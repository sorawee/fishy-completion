#lang racket/base

(require racket/set
         racket/class
         racket/list
         racket/string
         racket/format
         syntax/parse
         drracket/check-syntax
         quickscript)

(script-help-string
 "A proof-of-concept completion with fishy static analysis.")

;; assume that the buffer has number of characters less than `magic-number`
(define magic-number 1000000000)
;; assume that each identifier has length less than `magic-number*`
(define magic-number* 100000)
(define magic-inkantation 'fishy-completion-SEgTjuZhS1) ; generated from random.org

(define the-submod
  `(module ,magic-inkantation racket/base
     (require (for-syntax racket/base))
     (provide ,magic-inkantation (rename-out [@#%top #%top]))
     (define-syntax (@#%top stx)
       (syntax-case stx ()
         [(_ . x) #'(void)]))
     (define-syntax (,magic-inkantation stx)
       (syntax-case stx ()
         [(_ id ...)
          (syntax-property
           #'(void)
           'disappeared-use
           (map syntax-local-introduce (syntax->list #'(id ...))))]))))

;; Check Syntax only provides us starting and ending position.
;; How do we recover the actual identifier?
;;
;; Here's the idea: each identifier will adjust its srcloc to the position =
;; magic-number + (magic-number* * i) where i is the i-th candidate.
;; Once we get a position information, we can do math to compute i.
;; Note that syntax with sub-range-binders will adjust its position automatically
;; but this shouldn't offset things significantly, so the scheme
;; should still work

;; analyze :: syntax? (listof identifier?) -> (setof string?)
(define (analyze stx ids)
  (define vec (list->vector ids))
  (for/set ([entry (in-list (show-content stx))]
            #:when (eq? 'syncheck:add-arrow/name-dup/pxpy (vector-ref entry 0))
            ;; only care about local bindings
            #:when (not (vector-ref entry 11))
            ;; only interested in our instrumented code
            #:when (>= (vector-ref entry 5) magic-number))
    (~s (syntax-e (vector-ref vec (quotient (- (vector-ref entry 5) magic-number)
                                            magic-number*))))))

;; find-candidates :: syntax? string? -> (listof identifier?)
(define (find-candidates form prefix)
  (define locals (mutable-set))
  (define ns (make-base-namespace))
  (define stx (with-handlers ([exn:fail? (λ (_) #f)])
                (parameterize ([current-namespace ns]) (expand form))))
  (cond
    [stx
     (let loop ([stx stx])
       (syntax-parse stx
         [(a . b)
          (loop #'a)
          (loop #'b)]
         [x:id
          #:when (string-prefix? (~s (syntax-e #'x)) prefix)
          (set-add! locals (syntax-e #'x))]
         [_ (void)]))
     (for/list ([x (in-set locals)]
                [i (in-naturals)])
       (datum->syntax the-id
                      x
                      (list (syntax-source the-id)
                            1
                            0
                            (+ (* magic-number* i) magic-number 1)
                            0)
                      the-id))]
    [else '()]))

(define the-id #f)

(define-syntax-class idable
  (pattern x:id)
  ;; number could potentially be an identifier once completed
  (pattern x:number))

;; replace :: syntax? exact-positive-integer? any/c -> syntax?
(define (replace top-stx position new-stx)
  (syntax-parse top-stx
    [(mod name lang {~and mb-pair (mb . mb-body)})
     (define mb-body*
       (let loop ([stx #'mb-body])
         (syntax-parse stx
           [() this-syntax]
           [(a . b) (datum->syntax this-syntax
                                   (cons (loop #'a) (loop #'b))
                                   this-syntax
                                   this-syntax)]
           [x:idable
            #:when (and (syntax-source #'x)
                        (syntax-position #'x)
                        (syntax-span #'x)
                        (equal? (syntax-source #'x) (syntax-source top-stx))
                        (<= (add1 (syntax-position #'x))
                            position
                            (+ (syntax-position #'x) (syntax-span #'x))))
            (set! the-id #'x)
            (datum->syntax this-syntax new-stx this-syntax this-syntax)]
           [_ this-syntax])))
     (datum->syntax
      this-syntax
      (list #'mod #'name #'lang (datum->syntax
                                 #'mb-pair
                                 (list* #'mb
                                        the-submod
                                        `(require ',magic-inkantation)
                                        mb-body*)
                                 #'mb-pair
                                 #'mb-pair))
      this-syntax
      this-syntax)]))

;; my-read :: string? -> (or/c #f syntax?)
(define (my-read s)
  (define p (open-input-string s))
  (port-count-lines! p)
  (with-handlers ([exn:fail? (λ (_) #f)])
    (parameterize ([read-accept-reader #t])
      (read-syntax (string->path "dummy") p))))

;; query :: exact-positive-integer? string? ->
;;          (either (values #f #f '()) (values string? string? (listof string?)))
(define (query position code-str)
  (with-cache (list position code-str)
    (define orig-stx (my-read code-str))
    (cond
      [orig-stx
       (set! the-id #f)
       (define replaced (replace orig-stx position #t))
       (cond
         [the-id
          (define as-string (~s (syntax-e the-id)))
          (define as-list (string->list (if (= (+ 2 (string-length as-string))
                                               (syntax-span the-id))
                                            (string-append "|" as-string "|")
                                            as-string)))
          (define-values (left right)
            (split-at as-list (- position (syntax-position the-id))))
          (define left* (list->string left))
          (define right* (list->string right))
          (define candidates (find-candidates replaced left*))
          (values
           left*
           right*
           (cond
             [(empty? candidates) '()]
             [else
              (define stx/candidates
                (replace orig-stx position (cons magic-inkantation candidates)))
              (sort (set->list (analyze stx/candidates candidates)) string<?)]))]
         [else (values #f #f '())])]
      [else (values #f #f '())])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define cached (cons #f #f))

(define (cache-proc key proc)
  (cond
    [(equal? (car cached) key) (apply values (cdr cached))]
    [else (call-with-values proc
                            (λ xs
                              (set! cached (cons key xs))
                              (apply values xs)))]))

(define-syntax-rule (with-cache key body ...)
  (cache-proc key (λ () body ...)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Adapted from https://github.com/Metaxal/quickscript-extra/blob/master/scripts/dynamic-abbrev.rkt
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-script fishy-completion
  #:label "Fishy completion"
  #:shortcut #\,
  #:shortcut-prefix (ctl)
  #:persistent
  (λ (_sel #:editor ed)
    (define pos (send ed get-end-position))
    (define txt (send ed get-text))
    (define-values (left right matches)
      (query (add1 pos) txt))
    (unless (empty? matches)
      (define mems (member (string-append left right) matches))
      (define str
        (if (and mems (not (empty? (rest mems))))
            (second mems)
            (first matches)))
      (when str
        (define right* (substring str (string-length left)))
        (send ed begin-edit-sequence)
        (send ed delete pos (+ pos (string-length right)))
        (send ed insert right*)
        (send ed set-position pos)
        (send ed end-edit-sequence)
        (set! cached (cons (list (add1 pos) (send ed get-text))
                           (list left right* matches)))))
    #f))
