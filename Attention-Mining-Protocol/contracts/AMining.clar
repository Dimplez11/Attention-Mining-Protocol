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