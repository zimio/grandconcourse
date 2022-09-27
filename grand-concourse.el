;;; grand-concourse.el --- simple major mode for managing concourse jobs. -*- coding: utf-8; lexical-binding: t; -*-

;; Copyright © 2022 Jefry Lagrange

;; Author: Jefry Lagrange (jefry.reyes@gmail.com)
;; Version: 0.0.1
;; Created: 05 Aug 2022
;; Keywords: concourse
;; Homepage: -----

;; This file is not part of GNU Emacs.

;;; License:

;; You can redistribute this program and/or modify it under the terms of the GNU General Public License version 3.

;;; Commentary:

;; short description here

;; full doc on how to use here

(require 'subr-x)

(defgroup grand-concourse nil
  "Settings for grand-concourse package."
  :group 'external)

(defcustom grand-concourse-fly-path "/usr/local/bin/fly"
  "Specifies the path of the fly command binary"
  :group 'grand-concourse
  :type 'string)

(defcustom grand-concourse-target "b-anti-social"
  "Target name to operate in concourse"
  :group 'grand-concourse
  :type 'string)

(defvar grand-concourse--login-buffer "*concourse-login*"
  "Defines the name of the temporary buffer for the login command.")

(define-derived-mode grand-concourse-pipelines-mode tabulated-list-mode "Pipelines Menu"
  "Major mode for handling a list of pipelines."
  (setq tabulated-list-padding 2)
  (setq tabulated-list-format [("Pipelines" 18 t)])
  ;; (add-hook 'tabulated-list-revert-hook 'docker-container-refresh nil t)
  (tabulated-list-init-header))

(define-derived-mode grand-concourse-jobs-mode tabulated-list-mode "Jobs Menu"
  "Major mode for handling a list of jobs for a particular pipeline."
  (setq tabulated-list-padding 2)
  (setq tabulated-list-format [("Name" 50 t)
                               ("Paused" 10 t)
                               ("Status" 15 t)
                               ("Next" 14 t)])
  (tabulated-list-init-header))

(define-derived-mode grand-concourse-builds-mode tabulated-list-mode "Builds Menu"
  "Major mode for handling a list of builds for a particular job."
  (setq tabulated-list-padding 2)
  (setq tabulated-list-format [("Name" 10 t)
                               ("Status" 10 t)
                               ("Duration" 15 t)
                               ("Created by" 15 t)])
  (setq tabulated-list-sort-key  '("Name" . t))
  (tabulated-list-init-header))

(defun grand-concourse-login ()
  "Opens browser window with url to allow login into concourse."
  (interactive)
  (when
    (get-buffer grand-concourse--login-buffer)
    (kill-buffer grand-concourse--login-buffer))
  (start-process-shell-command
    "flylogin"
    grand-concourse--login-buffer
    (format "fly -t %s login" grand-concourse-target))
  ;; Sleep to wait for the output to show
  (sleep-for 2)
  (with-current-buffer
    grand-concourse--login-buffer
    (goto-char (point-min))
    (re-search-forward "https://.*[0-9]+")
    (browse-url (match-string 0))))

(defun grand-concourse--get-pipeline-name (output-line)
  (second (split-string output-line)))

(defun grand-concourse--entries-as-vector (entries)
  (if (stringp entries)
      (vector entries)
      (vconcat [] entries)))

(defun grand-concourse--format-as-tabulated-list (entries)
  (let ((entry-id 0)
        (tabulated-list '()))
    (dolist (entry entries)
            (push (list
                    entry-id
                    (grand-concourse--entries-as-vector entry))
                  tabulated-list)
            (setq entry-id (1+ entry-id)))
    tabulated-list))

(defun grand-concourse--format-as-tabulated-list-with-id (entries)
  (let ((tabulated-list '()))
    (dolist (entry entries)
      (push (list
             (first entry)
             (grand-concourse--entries-as-vector (rest entry)))
            tabulated-list))
    tabulated-list))

(defun grand-concourse--show-pipeline-list (pipeline-list)
  (grand-concourse--show-tabulated-list
   pipeline-list "*grand-concourse-pipelines*" #'grand-concourse-pipelines-mode))

(defun grand-concourse--show-job-list (job-list pipeline)
  (grand-concourse--show-tabulated-list
   job-list
   (format "*grand-concourse-jobs-[%s]*" pipeline)
   #'grand-concourse-jobs-mode)
  (make-local-variable 'selected-pipeline)
  (setq selected-pipeline pipeline))

(defun grand-concourse--show-tabulated-list (entries buffer-name mode &optional entries-with-id)
  (pop-to-buffer buffer-name)
  (funcall mode)
  (setq tabulated-list-entries
        (if entries-with-id
            (grand-concourse--format-as-tabulated-list-with-id entries)
            (grand-concourse--format-as-tabulated-list entries)))
  (tabulated-list-print t))

(defun grand-concourse-list-pipelines ()
  "Lists all available pipelines. Jobs can be accessed by pressing 'x' on of a pipeline."
  (interactive)
  (let* (
          (command-output
            (shell-command-to-string
              (format "fly -t %s pipelines" grand-concourse-target)))
          (pipeline-list
            (delete nil (mapcar #'grand-concourse--get-pipeline-name (split-string command-output "\n")))))
    (if (string-equal "authorized." (first pipeline-list))
      (user-error "Unauthorized, please make sure target is set and you are logged in. Use grand-concourse-login for login in.")
      (grand-concourse--show-pipeline-list pipeline-list))))

;; list jobs
;; fly -t b-anti-social js -p overdraft-service

(defun grand-concourse-list-jobs (pipeline)
  "Lists all available jobs for a particular pipeline.
   Builds can be accessed by pressing 'x' on of a job."
  (let* (
          (command-output
              (shell-command-to-string
              (format "fly -t %s js -p %s" grand-concourse-target pipeline)))
          (job-list (delete nil (mapcar #'split-string (split-string command-output "\n")))))
    (grand-concourse--show-job-list job-list pipeline)))

;; list builds

(defun grand-concourse--show-builds (builds)
  (grand-concourse--show-tabulated-list
    builds "*grand-concourse-builds*" #'grand-concourse-builds-mode t))

;; fly -t b-anti-social builds -j  overdraft-service/test

(defun grand-concourse--pick-build-columns (build)
  (list (first build)  (first (last (split-string (second build) "/"))) (third build) (sixth build) (eighth build)))

(defun grand-concourse-list-builds (job pipeline)
  "Lists all available builds for a particular job.
   Logs for the builds can be accessed by pressing 'x' on of the build."
  (let* (
          (command-output
              (shell-command-to-string
              (format "fly -t %s builds -j %s/%s" grand-concourse-target pipeline job)))
          (builds (mapcar #'grand-concourse--pick-build-columns
                          (delete nil (mapcar #'split-string (split-string command-output "\n"))))))
    (grand-concourse--show-builds builds)))
;; build output
;; fly -t b-anti-social watch --job overdraft-service/test --build 157.4


(defun grand-concourse--watch-build (build-id buffer-name)
  (pop-to-buffer buffer-name)
  (delete-other-windows)
  (ansi-color-for-comint-mode-on)
  (comint-mode)
  (set-process-filter
     (start-process-shell-command
       "flywatch"
        buffer-name
        (format
          "fly -t %s watch --build %s"
          grand-concourse-target
          build-id))
     'comint-output-filter))

(defun grand-concourse--execute-list-builds ()
 (interactive)
  (grand-concourse-list-builds (current-word) selected-pipeline))

(defun grand-concourse--execute-list-jobs ()
  (interactive)
  (grand-concourse-list-jobs (current-word)))

(defun grand-concourse--execute-watch-build ()
  (interactive)
  (let* ((word-split (split-string (current-word) "/"))
         (build (third word-split))
         (build-id (tabulated-list-get-id))
         (pipeline-and-job (string-join
                             (list (first word-split) (second word-split)) "/"))
         (build-output-buffer-name (generate-new-buffer-name (format "build-output-%s-%s" pipeline-and-job build))))
    (grand-concourse--watch-build build-id build-output-buffer-name)))

(defvar grand-concourse-pipelines-mode-map nil "Keymap for `grand-concourse-pipelines-mode'")

(progn
  (setq grand-concourse-pipelines-mode-map (make-sparse-keymap))
  (define-key grand-concourse-pipelines-mode-map (kbd "x") 'grand-concourse--execute-list-jobs))

(defvar grand-concourse-jobs-mode-map nil "Keymap for `grand-concourse-jobs-mode'")

(progn
  (setq grand-concourse-jobs-mode-map (make-sparse-keymap))
  (define-key grand-concourse-jobs-mode-map (kbd "x") 'grand-concourse--execute-list-builds))

(defvar grand-concourse-builds-mode-map nil "Keymap for `grand-concourse-builds-mode'")

(progn
  (setq grand-concourse-builds-mode-map (make-sparse-keymap))
  (define-key grand-concourse-builds-mode-map (kbd "x") 'grand-concourse--execute-watch-build))


(provide 'grand-concourse)
