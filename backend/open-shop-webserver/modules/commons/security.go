package commons

import (
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
)

// MaxBytesReader limits request body size (1MB)
const MaxRequestBodySize = 1 << 20 // 1MB

// DecodeJSONBody safely decodes JSON with size limits
func DecodeJSONBody(w http.ResponseWriter, r *http.Request, dst interface{}) error {
	r.Body = http.MaxBytesReader(w, r.Body, MaxRequestBodySize)
	defer func(Body io.ReadCloser) {
		err := Body.Close()
		if err != nil {
			slog.ErrorContext(r.Context(), "Error closing body: %v", err)
		}
	}(r.Body)

	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	if err := decoder.Decode(dst); err != nil {
		if err == io.EOF {
			http.Error(w, "request body is empty", http.StatusBadRequest)
			return err
		}
		http.Error(w, "invalid request body", http.StatusBadRequest)
		return err
	}

	return nil
}

// EncodeJSON writes JSON response with Content-Type header
func EncodeJSON(w http.ResponseWriter, status int, data interface{}) error {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		slog.Error("failed to encode JSON response", "error", err)
		return err
	}
	return nil
}
