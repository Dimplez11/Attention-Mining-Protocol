;; Attention Mining Protocol Smart Contract
;; A decentralized protocol for rewarding user attention and content engagement

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-UNAUTHORIZED (err u105))
(define-constant ERR-INVALID-DURATION (err u106))
(define-constant ERR-CAMPAIGN-ENDED (err u107))
(define-constant ERR-CAMPAIGN-ACTIVE (err u108))
(define-constant ERR-INVALID-THRESHOLD (err u109))

;; Token configuration
(define-fungible-token attention-token)
(define-constant TOKEN-NAME "Attention Mining Token")
(define-constant TOKEN-SYMBOL "ATTN")
(define-constant TOKEN-DECIMALS u6)
(define-constant MAX-SUPPLY u1000000000000) ;; 1M tokens with 6 decimals

;; Data Variables
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-campaigns uint u0)
(define-data-var base-reward uint u1000) ;; Base reward per interaction
(define-data-var quality-multiplier uint u150) ;; 1.5x for quality content
(define-data-var governance-threshold uint u100000) ;; Tokens needed for governance

;; Data Maps
(define-map user-profiles
  { user: principal }
  {
    total-attention: uint,
    reputation-score: uint,
    last-activity: uint,
    total-earned: uint,
    is-validator: bool
  }
)

(define-map content-items
  { content-id: uint }
  {
    creator: principal,
    content-hash: (string-ascii 64),
    category: (string-ascii 32),
    total-attention: uint,
    quality-score: uint,
    timestamp: uint,
    is-validated: bool,
    reward-pool: uint
  }
)
(define-map attention-records
  { user: principal, content-id: uint }
  {
    attention-duration: uint,
    interaction-type: (string-ascii 16),
    timestamp: uint,
    quality-rating: uint,
    reward-earned: uint
  }
)

(define-map campaigns
  { campaign-id: uint }
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    reward-pool: uint,
    total-distributed: uint,
    start-block: uint,
    end-block: uint,
    min-attention-duration: uint,
    target-category: (string-ascii 32),
    is-active: bool
  }
)

(define-map validators
  { validator: principal }
  {
    stake-amount: uint,
    validation-count: uint,
    accuracy-score: uint,
    last-validation: uint,
    is-active: bool
  }
)

(define-map governance-proposals
  { proposal-id: uint }
  {
    proposer: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    proposal-type: (string-ascii 32),
    target-value: uint,
    votes-for: uint,
    votes-against: uint,
    start-block: uint,
    end-block: uint,
    executed: bool
  }
)

(define-map governance-votes
  { proposal-id: uint, voter: principal }
  { vote-power: uint, vote-choice: bool }
)


;; Private Functions
(define-private (calculate-attention-reward (duration uint) (quality uint) (multiplier uint))
  (let
    (
      (base-calc (* (var-get base-reward) duration))
      (quality-bonus (* base-calc quality))
      (final-calc (/ quality-bonus u100))
    )
    (if (> multiplier u100)
      (/ (* final-calc multiplier) u100)
      final-calc
    )
  )
)

(define-private (update-reputation (user principal) (points uint))
  (let
    (
      (current-profile (default-to 
        { total-attention: u0, reputation-score: u0, last-activity: u0, total-earned: u0, is-validator: false }
        (map-get? user-profiles { user: user })
      ))
    )
    (map-set user-profiles
      { user: user }
      (merge current-profile { reputation-score: (+ (get reputation-score current-profile) points) })
    )
  )
)

(define-private (is-valid-validator (validator principal))
  (match (map-get? validators { validator: validator })
    validator-data (and (get is-active validator-data) (>= (get accuracy-score validator-data) u75))
    false
  )
)

;; Public Functions

;; Token Management
(define-public (mint-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-OWNER-ONLY)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ (ft-get-supply attention-token) amount) MAX-SUPPLY) ERR-INVALID-AMOUNT)
    (ft-mint? attention-token amount recipient)
  )
)

(define-public (transfer-tokens (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-transfer? attention-token amount tx-sender recipient)
  )
)

;; User Profile Management
(define-public (create-user-profile)
  (let
    (
      (existing-profile (map-get? user-profiles { user: tx-sender }))
    )
    (asserts! (is-none existing-profile) ERR-ALREADY-EXISTS)
    (ok (map-set user-profiles
      { user: tx-sender }
      {
        total-attention: u0,
        reputation-score: u100,
        last-activity: block-height,
        total-earned: u0,
        is-validator: false
      }
    ))
  )
)

(define-public (update-user-activity)
  (let
    (
      (current-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR-NOT-FOUND))
    )
    (ok (map-set user-profiles
      { user: tx-sender }
      (merge current-profile { last-activity: block-height })
    ))
  )
)

;; Content Management
(define-public (submit-content (content-hash (string-ascii 64)) (category (string-ascii 32)))
  (let
    (
      (content-id (+ (var-get total-campaigns) u1))
    )
    (asserts! (> (len content-hash) u0) ERR-INVALID-AMOUNT)
    (asserts! (> (len category) u0) ERR-INVALID-AMOUNT)
    
    (map-set content-items
      { content-id: content-id }
      {
        creator: tx-sender,
        content-hash: content-hash,
        category: category,
        total-attention: u0,
        quality-score: u50,
        timestamp: block-height,
        is-validated: false,
        reward-pool: u0
      }
    )
    
    (var-set total-campaigns content-id)
    (try! (update-user-activity))
    (ok content-id)
  )
)

;; Attention Recording
(define-public (record-attention (content-id uint) (duration uint) (interaction-type (string-ascii 16)))
  (let
    (
      (content-data (unwrap! (map-get? content-items { content-id: content-id }) ERR-NOT-FOUND))
      (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR-NOT-FOUND))
      (quality-rating u75)
      (reward-amount (calculate-attention-reward duration quality-rating (var-get quality-multiplier)))
    )
    
    (asserts! (> duration u0) ERR-INVALID-DURATION)
    (asserts! (>= duration u30) ERR-INVALID-DURATION) ;; Minimum 30 seconds
    
    ;; Record attention
    (map-set attention-records
      { user: tx-sender, content-id: content-id }
      {
        attention-duration: duration,
        interaction-type: interaction-type,
        timestamp: block-height,
        quality-rating: quality-rating,
        reward-earned: reward-amount
      }
    )
    
    ;; Update content stats
    (map-set content-items
      { content-id: content-id }
      (merge content-data { 
        total-attention: (+ (get total-attention content-data) duration)
      })
    )
    
    ;; Update user profile
    (map-set user-profiles
      { user: tx-sender }
      (merge user-profile {
        total-attention: (+ (get total-attention user-profile) duration),
        total-earned: (+ (get total-earned user-profile) reward-amount),
        last-activity: block-height
      })
    )
    
    ;; Mint reward tokens
    (try! (as-contract (ft-mint? attention-token reward-amount tx-sender)))
    (try! (update-reputation tx-sender (/ duration u60))) ;; 1 point per minute
    
    (ok reward-amount)
  )
)

;; Validator System
(define-public (become-validator (stake-amount uint))
  (begin
    (asserts! (>= stake-amount u10000) ERR-INVALID-AMOUNT) ;; Minimum stake
    (asserts! (>= (ft-get-balance attention-token tx-sender) stake-amount) ERR-INSUFFICIENT-BALANCE)
    
    (try! (ft-transfer? attention-token stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set validators
      { validator: tx-sender }
      {
        stake-amount: stake-amount,
        validation-count: u0,
        accuracy-score: u100,
        last-validation: block-height,
        is-active: true
      }
    )
    
    (let
      (
        (user-profile (unwrap! (map-get? user-profiles { user: tx-sender }) ERR-NOT-FOUND))
      )
      (map-set user-profiles
        { user: tx-sender }
        (merge user-profile { is-validator: true })
      )
    )
    
    (ok true)
  )
)

(define-public (validate-content (content-id uint) (quality-score uint))
  (let
    (
      (content-data (unwrap! (map-get? content-items { content-id: content-id }) ERR-NOT-FOUND))
      (validator-data (unwrap! (map-get? validators { validator: tx-sender }) ERR-NOT-FOUND))
    )
    
    (asserts! (is-valid-validator tx-sender) ERR-UNAUTHORIZED)
    (asserts! (<= quality-score u100) ERR-INVALID-AMOUNT)
    (asserts! (not (get is-validated content-data)) ERR-ALREADY-EXISTS)
    
    ;; Update content validation
    (map-set content-items
      { content-id: content-id }
      (merge content-data {
        quality-score: quality-score,
        is-validated: true
      })
    )
    
    ;; Update validator stats
    (map-set validators
      { validator: tx-sender }
      (merge validator-data {
        validation-count: (+ (get validation-count validator-data) u1),
        last-validation: block-height
      })
    )
    
    ;; Reward validator
    (try! (as-contract (ft-mint? attention-token u500 tx-sender)))
    
    (ok true)
  )
)

;; Campaign Management
(define-public (create-campaign 
    (title (string-ascii 64))
    (description (string-ascii 256))
    (reward-pool uint)
    (duration uint)
    (min-attention uint)
    (category (string-ascii 32))
  )
  (let
    (
      (campaign-id (+ (var-get total-campaigns) u1))
    )
    (asserts! (> reward-pool u0) ERR-INVALID-AMOUNT)
    (asserts! (> duration u0) ERR-INVALID-DURATION)
    (asserts! (>= (ft-get-balance attention-token tx-sender) reward-pool) ERR-INSUFFICIENT-BALANCE)
    
    (try! (ft-transfer? attention-token reward-pool tx-sender (as-contract tx-sender)))
    
    (map-set campaigns
      { campaign-id: campaign-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        reward-pool: reward-pool,
        total-distributed: u0,
        start-block: block-height,
        end-block: (+ block-height duration),
        min-attention-duration: min-attention,
        target-category: category,
        is-active: true
      }
    )
    
    (var-set total-campaigns campaign-id)
    (ok campaign-id)
  )
)

;; Governance
(define-public (create-proposal 
    (title (string-ascii 64))
    (description (string-ascii 256))
    (proposal-type (string-ascii 32))
    (target-value uint)
  )
  (let
    (
      (proposal-id (+ (var-get total-campaigns) u1))
      (user-balance (ft-get-balance attention-token tx-sender))
    )
    (asserts! (>= user-balance (var-get governance-threshold)) ERR-UNAUTHORIZED)
    
    (map-set governance-proposals
      { proposal-id: proposal-id }
      {
        proposer: tx-sender,
        title: title,
        description: description,
        proposal-type: proposal-type,
        target-value: target-value,
        votes-for: u0,
        votes-against: u0,
        start-block: block-height,
        end-block: (+ block-height u1440), ;; ~10 days
        executed: false
      }
    )
    
    (ok proposal-id)
  )
)

(define-public (vote-on-proposal (proposal-id uint) (vote-for bool))
  (let
    (
      (proposal-data (unwrap! (map-get? governance-proposals { proposal-id: proposal-id }) ERR-NOT-FOUND))
      (user-balance (ft-get-balance attention-token tx-sender))
      (existing-vote (map-get? governance-votes { proposal-id: proposal-id, voter: tx-sender }))
    )
    (asserts! (> user-balance u0) ERR-INSUFFICIENT-BALANCE)
    (asserts! (< block-height (get end-block proposal-data)) ERR-CAMPAIGN-ENDED)
    (asserts! (is-none existing-vote) ERR-ALREADY-EXISTS)
    
    (map-set governance-votes
      { proposal-id: proposal-id, voter: tx-sender }
      { vote-power: user-balance, vote-choice: vote-for }
    )
    
    (map-set governance-proposals
      { proposal-id: proposal-id }
      (merge proposal-data
        (if vote-for
          { votes-for: (+ (get votes-for proposal-data) user-balance) }
          { votes-against: (+ (get votes-against proposal-data) user-balance) }
        )
      )
    )
    
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-token-balance (user principal))
  (ft-get-balance attention-token user)
)

(define-read-only (get-user-profile (user principal))
  (map-get? user-profiles { user: user })
)

(define-read-only (get-content-item (content-id uint))
  (map-get? content-items { content-id: content-id })
)

(define-read-only (get-attention-record (user principal) (content-id uint))
  (map-get? attention-records { user: user, content-id: content-id })
)

(define-read-only (get-campaign (campaign-id uint))
  (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-validator-info (validator principal))
  (map-get? validators { validator: validator })
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? governance-proposals { proposal-id: proposal-id })
)

(define-read-only (get-contract-info)
  {
    total-supply: (ft-get-supply attention-token),
    max-supply: MAX-SUPPLY,
    total-campaigns: (var-get total-campaigns),
    base-reward: (var-get base-reward),
    governance-threshold: (var-get governance-threshold)
  }
)

;; Initialize contract
(begin
  (try! (ft-mint? attention-token u100000000 CONTRACT-OWNER)) ;; Initial mint for bootstrapping
)