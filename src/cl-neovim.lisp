(in-package #:cl-neovim)


(setf mrpc::*encode-alist-as-map* NIL)
(setf mrpc:*extended-types* (mrpc::define-extension-types '(Buffer Window Tabpage)))
(setf mrpc::*decoder-prefers-lists* T)

(defvar *using-host* NIL "Variable that host binds to T when it loads plugins.")

(defvar *specs* NIL "A list of all the specs nvim needs.")
(defvar *path* "" "Variable that gets set to path to plugin.")
(defvar *nvim-instance* NIL "Binds to the last connection to neovim")


(defclass nvim (mrpc:client)
  ((client-id :initform NIL :reader client-id)))


(defmethod client-id :before ((instance nvim))
  (with-slots (client-id) instance
    (unless client-id
      (setf client-id (first (call/s instance "vim_get_api_info"))))))

(cl:defun parse-env-listen-address (address)
  (cond ((not (stringp address)) (error "$NVIM_LISTEN_ADDRESS not found"))
        ((find #\: address) (destructuring-bind (host port) (split-sequence:split-sequence #\: address)
                              `(:host ,host :port ,(parse-integer port))))
        ((probe-file address) `(:file ,address))
        (t (error (format NIL "Could not parse $NVIM_LISTEN_ADDRESS (~A)." address)))))

(cl:defun connect (&rest args &key host port file)
  (setf *nvim-instance* (apply #'make-instance 'nvim (or args (parse-env-listen-address (uiop:getenv "NVIM_LISTEN_ADDRESS"))))))

(cl:defun connect-stdio ()
  (setf *nvim-instance* (make-instance 'nvim)))

(cl:defun listen-once (&optional (instance *nvim-instance*))
  "Block execution listening for a new message for instance."
  (mrpc::run-once (mrpc::event-loop instance)))

(cl:defun %call (instance fn-type command &rest args)
  (let ((instance (etypecase instance
                    ((member t) *nvim-instance*)
                    (nvim instance))))
    (apply fn-type instance command args)))

(cl:defun call/s (instance command &rest args)
  "Send nvim command to neovim socket and return the result."
  (apply #'%call instance #'mrpc:request command args))

(cl:defun call/a (instance command &rest args)
  "Send nvim command to neovim socket asynchronously, returning the control
back to the caller immediately and discarding all return values/errors."
  (apply #'%call instance #'mrpc:notify command args))
