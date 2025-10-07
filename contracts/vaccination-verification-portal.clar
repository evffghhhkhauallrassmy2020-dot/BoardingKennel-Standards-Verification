;; title: vaccination-verification-portal
;; version: 1.0.0
;; summary: Record vaccination attestations for pets/guests and query their status.
;; description: Standalone contract with simple ownership model. No cross-contract calls, no traits.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and errors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-constant ERR-NOT-FOUND (err u200))
(define-constant ERR-NOT-AUTHORIZED (err u201))
(define-constant ERR-BAD-PARAMS (err u202))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data vars
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-data-var next-pet-id uint u1)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data maps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; pet-id => { owner, species, name, created-at }
(define-map pets
  { id: uint }
  { owner: principal,
    species: (string-ascii 24),
    name: (string-ascii 64),
    created-at: uint })

;; vaccination keyed by (pet-id, vacc-code)
(define-map vaccinations
  { pet-id: uint, vacc-code: (string-ascii 32) }
  { date: uint,
    by: principal,
    revoked: bool,
    revoke-reason: (optional (string-ascii 64)) })

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers (private)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-private (only-owner (pet-id uint))
  (match (map-get? pets { id: pet-id })
    data (if (is-eq (get owner data) tx-sender) (ok true) ERR-NOT-AUTHORIZED)
    ERR-NOT-FOUND))

(define-private (non-empty (s (string-ascii 64)))
  (> (len s) u0))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public entrypoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-public (register-pet (species (string-ascii 24)) (name (string-ascii 64)) (created-at uint))
  (begin
    (asserts! (non-empty name) ERR-BAD-PARAMS)
    (asserts! (> (len species) u0) ERR-BAD-PARAMS)
    (let ((new-id (var-get next-pet-id)))
      (map-set pets { id: new-id }
              { owner: tx-sender,
                species: species,
                name: name,
                created-at: created-at })
      (var-set next-pet-id (+ new-id u1))
      (ok new-id))))

(define-public (attest-vaccination (pet-id uint)
                                   (vacc-code (string-ascii 32))
                                   (date uint))
  (begin
    (asserts! (is-ok (only-owner pet-id)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len vacc-code) u0) ERR-BAD-PARAMS)
    (map-set vaccinations { pet-id: pet-id, vacc-code: vacc-code }
             { date: date, by: tx-sender, revoked: false, revoke-reason: none })
    (ok true)))

(define-public (revoke-vaccination (pet-id uint)
                                   (vacc-code (string-ascii 32))
                                   (reason (string-ascii 64)))
  (begin
    (asserts! (is-ok (only-owner pet-id)) ERR-NOT-AUTHORIZED)
    (match (map-get? vaccinations { pet-id: pet-id, vacc-code: vacc-code })
      v
      (begin
        (map-set vaccinations { pet-id: pet-id, vacc-code: vacc-code }
                 { date: (get date v),
                   by: (get by v),
                   revoked: true,
                   revoke-reason: (some reason) })
        (ok true))
      ERR-NOT-FOUND)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-only entrypoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-read-only (get-pet (pet-id uint))
  (map-get? pets { id: pet-id }))

(define-read-only (get-vaccination (pet-id uint) (vacc-code (string-ascii 32)))
  (map-get? vaccinations { pet-id: pet-id, vacc-code: vacc-code }))

(define-read-only (has-valid-vaccination (pet-id uint) (vacc-code (string-ascii 32)))
  (match (map-get? vaccinations { pet-id: pet-id, vacc-code: vacc-code })
    v (ok (and (not (get revoked v)) (> (get date v) u0)))
    (ok false)))

(define-read-only (get-next-pet-id)
  (ok (var-get next-pet-id)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
