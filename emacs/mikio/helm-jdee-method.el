;;; helm-jdee-method.el --- JDEE method helm interface

;; Copyright (C) 2012 by Mikio

;; Author: mikio <tiwtter: @mikio_kun>
;; URL: https://github.com/mikio/emacs-helm-jdee-method
;; Version: 0.1
;; Package-Requires: ((helm "1.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:


;;; Code:
(require 'helm)
(require 'jde)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; auto-complete
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TODO 型ごとのメソッド一覧を、バッファローカルの連想リストに保存して再利用するようにする。
;;(make-variable-buffer-local 'mikio/lvar-methods)
(defvar mikio/lvar-methods nil)

(defun ac-source-jdee-candidates ()
  (with-current-buffer helm-current-buffer
    (setq bsh-eval-timeout 5)
    (let ((l (mikio/jde-get-methods)))
      ;;(message "end..%s" l)
      l
      )))

(defun mikio/jde-debug ()
  (interactive)
  (message "%s" (mikio/jde-get-methods))
  )

(defun mikio/get-methods-from-cache (type)
  (unless mikio/lvar-methods
    (setq mikio/lvar-methods (make-hash-table :test 'equal)))
  (gethash type mikio/lvar-methods)
  )

(defun mikio/jde-get-methods ()
  (let* ((pair (mikio/jde-get-pair-))
         (type (jde-parse-eval-type-of (car pair)))
         (methods (mikio/get-methods-from-cache type)))
    (if methods
        (progn
          (message "auto-complete ...cache")
          methods
          )
      (message "auto-complete ...no cache")
      (setq methods (mikio/jde-get-methods- type pair))
      (puthash type methods mikio/lvar-methods)
      (message "hoge")
      )
    methods))

(defun mikio/jde-get-pair- ()
  (let* ((pair (jde-parse-java-variable-at-point)))
    ;;(message pair)
    (if pair
        (condition-case err
            (setq pair (jde-complete-get-pair pair nil))
          (error (condition-case err
                     (setq pair (jde-complete-get-pair pair t)))
                 (error (message "%s" (error-message-string err)))))
      (message "No completion at this point"))
    pair))

(defun mikio/jde-get-methods- (type pair)
  (let ((access (jde-complete-get-access pair)) ; this. なのか super. なのかでアクセスレベルを取得する(定数)
        (obj (car pair))
        completion-list)
    (progn
      (if access
          (setq completion-list
                (miki/jde-get-methods2- type access)) ; private, protecteのとき
        (setq completion-list (miki/jde-get-methods2- type))) ; publicレベルのとき

      ;;if the completion list is nil check if the method is in the current
      ;;class(this)
      (if (null completion-list)
          (setq completion-list (miki/jde-get-methods2-
                                 (list (concat "this." obj) "")
                                 jde-complete-private)))
      ;;if completions is still null check if the method is in the
      ;;super class
      (if (null completion-list)
          (setq completion-list (miki/jde-get-methods2-
                                 (list (concat "super." obj) "")
                                 jde-complete-protected)))

      (if completion-list
          completion-list
        (error "No completion at this point")))))

(defun miki/jde-get-methods2- (type &optional access-level)
  (if type
      (cond ((member type jde-parse-primitive-types)
             (error "Cannot complete primitive type: %s" type))
            ((string= type "void")
             (error "Cannot complete return type of %s is void." type))
            (t
             (let (l
                   (method-list (jde-complete-get-classinfo type access-level)))
               (dolist (v method-list)
                 ;;(setq l (cons (format "\"%s\"" (cdr v)) l))
                 ;; (setq l (cons (cdr v) l)))
                 (setq l (cons (car v) l)))
               l)
             )
            )
    nil))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(require 'cl)
(setq my-method "wait(long, int) : void throws java.lang.InterruptedException")

(defun my-jdee-method-split (s)
  (let ((ss (replace-regexp-in-string " +" "" (car (split-string s ":")))))
    ;;(message (concat "split ss:" ss))
    ss))

(defun my-jdee-method-list (s)
  (message (concat "s:" s))
  (let ((ss (my-jdee-method-split s)))
    ;;(message (concat "ss:" ss))
    (when (string-match "\\(.*\\)(\\(.*\\))" ss)
      (list (match-string 1 ss) (match-string 2 ss)))))

;;my-method ; => "wait(long, int) : void throws java.lang.InterruptedException"
;; (my-jdee-method-split my-method) 
;; (my-jdee-method-list my-method)

(defun my-jdee-method-name (l)
  (car l))

(defun my-jdee-method-args (l)
  (let ((arg (car (cdr l))))
    (split-string arg ",")))

;; (my-jdee-method-list my-method)
;;(my-jdee-method-create-snippet (my-jdee-method-args (my-jdee-method-list my-method)))

(defun my-jdee-method-create-snippet (l)
  (let ((len (length l)))
    (loop for i from 1 to len
          for x in l
          collect (format "${%s:%s}" i x))))
(setq args '("aa" "bb"))
(apply 'concat "hoge" args)


(defun my-jdee-method-action (s)
  "yasnippet用のテンプレートを動的に作成する。"
  (let* ((l (my-jdee-method-list s))
         (name (my-jdee-method-name l))
         (args (my-jdee-method-args l))
         (snip (apply 'concat (my-jdee-method-create-snippet args)))
         (snippet (concat name "(" snip ")"))
         )
    (message snippet)
    ;;(insert s)
    (yas/expand-snippet snippet)
    ;;(yas/expand-snippet "split(${1:String} , ${2:int})")
    ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(eval-when-compile (require 'cl))
(require 'helm)

(defgroup helm-jdee-method nil
  "JDEE method complation for helm"
  :group 'helm)

(defvar helm-c-source-jdee-method
  '((name . "jdee-method")
    (init . (lambda () ()))
    (candidates-in-buffer)
    (candidate-number-limit . 9999)
    (candidates . (lambda () (ac-source-jdee-candidates)))
    (action ("Insert" . my-jdee-method-action))))

(defun helm-jdee-method ()
  ""
  (interactive)
  (helm-other-buffer '(helm-c-source-jdee-method) "*helm-jdee-method*")
  )

;; (defvar helm-c-jdee-method-mode-name " HelmJdeM")
;; (defvar helm-c-jdee-method-mode-map (make-sparse-keymap))

;; ;;;###autoload
;; (define-minor-mode helm-jdee-method-mode ()
;;   "Enable for helm-jdee-method"
;;   :group      'helm-jdee-method
;;   :init-value nil
;;   :global     nil
;;   :keymap     helm-c-jdee-method-mode-map
;;   :lighter    helm-c-jdee-method-mode-name
;;   (if helm-jdee-method-mode
;;       (run-hooks 'helm-jdee-method-mode-hook)))

(provide 'helm-jdee-method)

;; Local Variables:
;; coding: utf-8
;; indent-tabs-mode: nil
;; End:

;;; helm-jdee-method.el ends here