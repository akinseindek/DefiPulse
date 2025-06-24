;; Decentralized Autonomous Investment Fund (DeFi ETF)
;; A smart contract that manages a decentralized investment fund where users can deposit STX,
;; receive fund tokens representing their share, and participate in governance decisions.
;; The fund automatically rebalances based on predefined strategies and community votes.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-FUND-PAUSED (err u104))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u105))
(define-constant ERR-ALREADY-VOTED (err u106))
(define-constant ERR-VOTING-PERIOD-ENDED (err u107))
(define-constant ERR-INSUFFICIENT-VOTING-POWER (err u108))

;; Fund token details
(define-fungible-token fund-token)
(define-constant TOKEN-NAME "DeFi ETF Token")
(define-constant TOKEN-SYMBOL "DETF")
(define-constant TOKEN-DECIMALS u6)

;; Data maps and variables
(define-data-var fund-paused bool false)
(define-data-var total-fund-value uint u0)
(define-data-var management-fee-rate uint u200) ;; 2% annual fee (200 basis points)
(define-data-var performance-fee-rate uint u1000) ;; 10% performance fee
(define-data-var min-deposit uint u1000000) ;; 1 STX minimum deposit
(define-data-var proposal-counter uint u0)

;; Track user deposits and withdrawals
(define-map user-deposits principal uint)
(define-map user-last-deposit-block principal uint)

;; Asset allocation tracking
(define-map asset-allocations 
  { asset: (string-ascii 10) }
  { 
    target-percentage: uint,
    current-amount: uint,
    last-rebalance-block: uint
  }
)

;; Governance proposals
(define-map proposals
  uint
  {
    proposer: principal,
    title: (string-ascii 50),
    description: (string-ascii 200),
    proposal-type: (string-ascii 20),
    target-value: uint,
    votes-for: uint,
    votes-against: uint,
    end-block: uint,
    executed: bool
  }
)

;; Track voting to prevent double voting
(define-map votes { proposal-id: uint, voter: principal } bool)

;; Private functions

;; Calculate management fee based on time elapsed
(define-private (calculate-management-fee (user-balance uint) (blocks-elapsed uint))
  (let ((annual-blocks u52560)) ;; Approximate blocks per year
    (/ (* (* user-balance (var-get management-fee-rate)) blocks-elapsed) (* annual-blocks u10000))
  )
)

;; Calculate fund token price based on total value and supply
(define-private (get-token-price)
  (let ((total-supply (ft-get-supply fund-token)))
    (if (is-eq total-supply u0)
      u1000000 ;; Initial price: 1 STX = 1 token
      (/ (var-get total-fund-value) total-supply)
    )
  )
)

;; Validate proposal parameters
(define-private (is-valid-proposal (proposal-type (string-ascii 20)) (target-value uint))
  (and
    (> target-value u0)
    (or 
      (is-eq proposal-type "rebalance")
      (is-eq proposal-type "fee-change")
      (is-eq proposal-type "asset-add")
    )
  )
)

;; Public functions

;; Initialize fund with basic asset allocations
(define-public (initialize-fund)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-OWNER-ONLY)
    ;; Set initial asset allocations (example: 60% STX, 40% stable)
    (map-set asset-allocations 
      { asset: "STX" }
      { target-percentage: u6000, current-amount: u0, last-rebalance-block: block-height }
    )
    (map-set asset-allocations 
      { asset: "STABLE" }
      { target-percentage: u4000, current-amount: u0, last-rebalance-block: block-height }
    )
    (ok true)
  )
)

;; Deposit STX and receive fund tokens
(define-public (deposit (amount uint))
  (let (
    (token-price (get-token-price))
    (tokens-to-mint (/ (* amount u1000000) token-price))
  )
    (asserts! (not (var-get fund-paused)) ERR-FUND-PAUSED)
    (asserts! (>= amount (var-get min-deposit)) ERR-INVALID-AMOUNT)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Mint fund tokens to user
    (try! (ft-mint? fund-token tokens-to-mint tx-sender))
    
    ;; Update tracking variables
    (map-set user-deposits tx-sender 
      (+ (default-to u0 (map-get? user-deposits tx-sender)) amount))
    (map-set user-last-deposit-block tx-sender block-height)
    (var-set total-fund-value (+ (var-get total-fund-value) amount))
    
    (ok tokens-to-mint)
  )
)

;; Withdraw by burning fund tokens
(define-public (withdraw (token-amount uint))
  (let (
    (token-price (get-token-price))
    (stx-amount (/ (* token-amount token-price) u1000000))
    (user-balance (ft-get-balance fund-token tx-sender))
  )
    (asserts! (not (var-get fund-paused)) ERR-FUND-PAUSED)
    (asserts! (>= user-balance token-amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Burn user's fund tokens
    (try! (ft-burn? fund-token token-amount tx-sender))
    
    ;; Transfer STX to user
    (try! (as-contract (stx-transfer? stx-amount tx-sender tx-sender)))
    
    ;; Update fund value
    (var-set total-fund-value (- (var-get total-fund-value) stx-amount))
    
    (ok stx-amount)
  )
)

;; Create governance proposal
(define-public (create-proposal 
  (title (string-ascii 50)) 
  (description (string-ascii 200))
  (proposal-type (string-ascii 20))
  (target-value uint)
)
  (let ((proposal-id (+ (var-get proposal-counter) u1)))
    (asserts! (> (ft-get-balance fund-token tx-sender) u0) ERR-INSUFFICIENT-VOTING-POWER)
    (asserts! (is-valid-proposal proposal-type target-value) ERR-INVALID-AMOUNT)
    
    (map-set proposals proposal-id
      {
        proposer: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        target-value: target-value,
        votes-for: u0,
        votes-against: u0,
        end-block: (+ block-height u1440), ;; ~24 hours voting period
        executed: false
      }
    )
    (var-set proposal-counter proposal-id)
    (ok proposal-id)
  )
)

;; Vote on proposal - FIXED VERSION
(define-public (vote (proposal-id uint) (support bool))
  (let (
    (proposal (unwrap! (map-get? proposals proposal-id) ERR-PROPOSAL-NOT-FOUND))
    (voter-power (ft-get-balance fund-token tx-sender))
    (vote-key { proposal-id: proposal-id, voter: tx-sender })
  )
    (asserts! (> voter-power u0) ERR-INSUFFICIENT-VOTING-POWER)
    (asserts! (is-none (map-get? votes vote-key)) ERR-ALREADY-VOTED)
    (asserts! (<= block-height (get end-block proposal)) ERR-VOTING-PERIOD-ENDED)
    
    ;; Record the vote
    (map-set votes vote-key true)
    
    ;; Update proposal vote counts - FIXED: Both arms return the same tuple type
    (if support
      ;; Support vote: increment votes-for
      (map-set proposals proposal-id
        (merge proposal { votes-for: (+ (get votes-for proposal) voter-power) })
      )
      ;; Against vote: increment votes-against  
      (map-set proposals proposal-id
        (merge proposal { votes-against: (+ (get votes-against proposal) voter-power) })
      )
    )
    (ok true)
  )
)

;; Read-only functions for getting fund information
(define-read-only (get-fund-info)
  {
    total-value: (var-get total-fund-value),
    token-supply: (ft-get-supply fund-token),
    token-price: (get-token-price),
    paused: (var-get fund-paused),
    management-fee: (var-get management-fee-rate),
    performance-fee: (var-get performance-fee-rate)
  }
)

(define-read-only (get-user-balance (user principal))
  (ft-get-balance fund-token user)
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals proposal-id)
)

