package apperr

import "net/http"

// AppError is a domain error that carries an HTTP status code and a user-facing message.
type AppError struct {
	Status  int
	Message string
	Details map[string]string
}

func (e *AppError) Error() string { return e.Message }

func BadRequest(msg string) *AppError  { return &AppError{Status: http.StatusBadRequest, Message: msg} }
func Unauthorized(msg string) *AppError { return &AppError{Status: http.StatusUnauthorized, Message: msg} }
func Forbidden(msg string) *AppError   { return &AppError{Status: http.StatusForbidden, Message: msg} }
func NotFound(msg string) *AppError    { return &AppError{Status: http.StatusNotFound, Message: msg} }
func Conflict(msg string) *AppError    { return &AppError{Status: http.StatusConflict, Message: msg} }
func Internal(msg string) *AppError    { return &AppError{Status: http.StatusInternalServerError, Message: msg} }

func BadRequestWithDetails(msg string, details map[string]string) *AppError {
	return &AppError{Status: http.StatusBadRequest, Message: msg, Details: details}
}
