package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/locationshare/backend/internal/apperr"
)

type errorBody struct {
	Timestamp time.Time         `json:"timestamp"`
	Status    int               `json:"status"`
	Error     string            `json:"error"`
	Message   string            `json:"message"`
	Details   map[string]string `json:"details,omitempty"`
}

var statusText = map[int]string{
	400: "Bad Request",
	401: "Unauthorized",
	403: "Forbidden",
	404: "Not Found",
	409: "Conflict",
	500: "Internal Server Error",
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, err error) {
	var ae *apperr.AppError
	if !errors.As(err, &ae) {
		ae = apperr.Internal("服务器内部错误")
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(ae.Status)
	_ = json.NewEncoder(w).Encode(errorBody{
		Timestamp: time.Now().UTC(),
		Status:    ae.Status,
		Error:     statusText[ae.Status],
		Message:   ae.Message,
		Details:   ae.Details,
	})
}

func decode(r *http.Request, v any) error {
	return json.NewDecoder(r.Body).Decode(v)
}
