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
