package commons

import (
	"fmt"
	"regexp"
	"strings"
)

// InputError represents a validation error
type InputError struct {
	Field   string
	Message string
}

// ValidationError wraps multiple input errors
type ValidationError struct {
	Errors []InputError
}

func (e ValidationError) Error() string {
	if len(e.Errors) == 0 {
		return "validation failed"
	}
	messages := make([]string, len(e.Errors))
	for i, err := range e.Errors {
		messages[i] = fmt.Sprintf("%s: %s", err.Field, err.Message)
	}
	return strings.Join(messages, "; ")
}

// Email validation
func validateEmail(email string) error {
	email = strings.TrimSpace(email)
	if email == "" {
		return fmt.Errorf("email is required")
	}
	if len(email) > 255 {
		return fmt.Errorf("email must be less than 255 characters")
	}

	// RFC 5322 simplified regex
	emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	if !emailRegex.MatchString(email) {
		return fmt.Errorf("invalid email format")
	}
	return nil
}

// Password validation
func validatePassword(password string) error {
	if password == "" {
		return fmt.Errorf("password is required")
	}
	if len(password) < 8 {
		return fmt.Errorf("password must be at least 8 characters")
	}
	if len(password) > 128 {
		return fmt.Errorf("password must be less than 128 characters")
	}

	// Check for at least one uppercase, one lowercase, one digit, one special char
	hasUpper := regexp.MustCompile(`[A-Z]`).MatchString(password)
	hasLower := regexp.MustCompile(`[a-z]`).MatchString(password)
	hasDigit := regexp.MustCompile(`[0-9]`).MatchString(password)
	hasSpecial := regexp.MustCompile(`[!@#$%^&*\-_=+]`).MatchString(password)

	if !hasUpper || !hasLower || !hasDigit || !hasSpecial {
		return fmt.Errorf("password must contain uppercase, lowercase, digit, and special character (!@#$%%^&*-_=+)")
	}
	return nil
}

// Name validation (first name, last name, etc.)
func validateName(name string, fieldName string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("%s is required", fieldName)
	}
	if len(name) > 50 {
		return fmt.Errorf("%s must be less than 50 characters", fieldName)
	}
	if len(name) < 2 {
		return fmt.Errorf("%s must be at least 2 characters", fieldName)
	}

	// Only alphanumeric, spaces, hyphens, apostrophes
	nameRegex := regexp.MustCompile(`^[a-zA-Z\s\-']+$`)
	if !nameRegex.MatchString(name) {
		return fmt.Errorf("%s can only contain letters, spaces, hyphens, and apostrophes", fieldName)
	}
	return nil
}

// Phone validation (E.164 format)
func validatePhone(phone string) error {
	phone = strings.TrimSpace(phone)
	if phone == "" {
		return nil // optional field
	}

	// E.164 format: +[1-9]{1,15}
	phoneRegex := regexp.MustCompile(`^\+?[1-9]\d{1,14}$`)
	if !phoneRegex.MatchString(phone) {
		return fmt.Errorf("invalid phone format (use E.164: +1234567890)")
	}
	return nil
}

// Country code validation (ISO 3166-1 alpha-2)
func validateCountryCode(code string) error {
	code = strings.ToUpper(strings.TrimSpace(code))
	if code == "" {
		return fmt.Errorf("country code is required")
	}
	if len(code) != 2 {
		return fmt.Errorf("country code must be exactly 2 characters")
	}

	// Check if it's valid ISO 3166-1 alpha-2
	validCountryCodes := map[string]bool{
		"US": true, "GB": true, "CA": true, "AU": true, "DE": true, "FR": true,
		"JP": true, "CN": true, "IN": true, "BR": true, "MX": true, "ES": true,
		"IT": true, "NL": true, "SE": true, "CH": true, "AT": true, "BE": true,
		"DK": true, "NO": true, "FI": true, "PL": true, "GR": true, "TR": true,
		"RU": true, "UA": true, "KR": true, "SG": true, "HK": true, "NZ": true,
		"ZA": true, "KE": true, "NG": true, "EG": true, "AR": true, "CL": true,
		"PE": true, "CO": true, "VE": true, "TH": true, "MY": true, "ID": true,
		"PH": true, "VN": true, "PK": true, "BD": true, "IR": true, "SA": true,
		"AE": true, "IL": true, "ZZ": true, // ZZ for testing
	}

	if !validCountryCodes[code] {
		return fmt.Errorf("invalid country code %s", code)
	}
	return nil
}

// Address line validation
func validateAddressLine(address string, fieldName string) error {
	address = strings.TrimSpace(address)
	if address == "" {
		return fmt.Errorf("%s is required", fieldName)
	}
	if len(address) > 100 {
		return fmt.Errorf("%s must be less than 100 characters", fieldName)
	}
	if len(address) < 5 {
		return fmt.Errorf("%s must be at least 5 characters", fieldName)
	}

	// Allow alphanumeric, spaces, common address characters
	addressRegex := regexp.MustCompile(`^[a-zA-Z0-9\s\-.,#&()]+$`)
	if !addressRegex.MatchString(address) {
		return fmt.Errorf("%s contains invalid characters", fieldName)
	}
	return nil
}

// City/State validation
func validateCity(city string, fieldName string) error {
	city = strings.TrimSpace(city)
	if city == "" {
		return fmt.Errorf("%s is required", fieldName)
	}
	if len(city) > 50 {
		return fmt.Errorf("%s must be less than 50 characters", fieldName)
	}
	if len(city) < 2 {
		return fmt.Errorf("%s must be at least 2 characters", fieldName)
	}

	cityRegex := regexp.MustCompile(`^[a-zA-Z\s\-'.]+$`)
	if !cityRegex.MatchString(city) {
		return fmt.Errorf("%s can only contain letters, spaces, hyphens, and apostrophes", fieldName)
	}
	return nil
}

// Postal code validation (simple - allows common formats)
func validatePostalCode(code string) error {
	code = strings.TrimSpace(code)
	if code == "" {
		return fmt.Errorf("postal code is required")
	}
	if len(code) > 20 {
		return fmt.Errorf("postal code must be less than 20 characters")
	}
	if len(code) < 3 {
		return fmt.Errorf("postal code must be at least 3 characters")
	}

	// Allow alphanumeric and common separators
	codeRegex := regexp.MustCompile(`^[a-zA-Z0-9\s\-]+$`)
	if !codeRegex.MatchString(code) {
		return fmt.Errorf("invalid postal code format")
	}
	return nil
}

// Company name validation (optional, permissive)
func validateCompanyName(company string) error {
	if company == "" {
		return nil // optional
	}
	if len(company) > 100 {
		return fmt.Errorf("company name must be less than 100 characters")
	}

	companyRegex := regexp.MustCompile(`^[a-zA-Z0-9\s\-.,&()]+$`)
	if !companyRegex.MatchString(company) {
		return fmt.Errorf("company name contains invalid characters")
	}
	return nil
}

// Sanitize string - trim whitespace
func sanitizeString(s string) string {
	return strings.TrimSpace(s)
}

// Sanitize email - lowercase and trim
func sanitizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

// SignupRequest validation
func validateSignupRequest(email, password, firstName, lastName string) error {
	var errors []InputError

	if err := validateEmail(email); err != nil {
		errors = append(errors, InputError{"email", err.Error()})
	}
	if err := validatePassword(password); err != nil {
		errors = append(errors, InputError{"password", err.Error()})
	}
	if err := validateName(firstName, "firstName"); err != nil {
		errors = append(errors, InputError{"firstName", err.Error()})
	}
	if err := validateName(lastName, "lastName"); err != nil {
		errors = append(errors, InputError{"lastName", err.Error()})
	}

	if len(errors) > 0 {
		return ValidationError{Errors: errors}
	}
	return nil
}

// AddressRequest validation
func validateAddressRequest(firstName, lastName, fullName, addressLine1, addressLine2, city, state, postalCode, country, phone string) error {
	var errors []InputError

	// Check if first_name and last_name OR full_name is provided
	if firstName == "" && lastName == "" && fullName == "" {
		errors = append(errors, InputError{"name", "either firstName/lastName or fullName is required"})
	} else {
		if firstName != "" || lastName != "" {
			if firstName == "" || lastName == "" {
				errors = append(errors, InputError{"name", "both firstName and lastName are required together"})
			} else {
				if err := validateName(firstName, "firstName"); err != nil {
					errors = append(errors, InputError{"firstName", err.Error()})
				}
				if err := validateName(lastName, "lastName"); err != nil {
					errors = append(errors, InputError{"lastName", err.Error()})
				}
			}
		} else {
			if err := validateName(fullName, "fullName"); err != nil {
				errors = append(errors, InputError{"fullName", err.Error()})
			}
		}
	}

	if err := validateAddressLine(addressLine1, "addressLine1"); err != nil {
		errors = append(errors, InputError{"addressLine1", err.Error()})
	}
	if addressLine2 != "" {
		if err := validateAddressLine(addressLine2, "addressLine2"); err != nil {
			errors = append(errors, InputError{"addressLine2", err.Error()})
		}
	}
	if err := validateCity(city, "city"); err != nil {
		errors = append(errors, InputError{"city", err.Error()})
	}
	if state != "" {
		if err := validateCity(state, "state"); err != nil {
			errors = append(errors, InputError{"state", err.Error()})
		}
	}
	if err := validatePostalCode(postalCode); err != nil {
		errors = append(errors, InputError{"postalCode", err.Error()})
	}
	if err := validateCountryCode(country); err != nil {
		errors = append(errors, InputError{"country", err.Error()})
	}
	if phone != "" {
		if err := validatePhone(phone); err != nil {
			errors = append(errors, InputError{"phone", err.Error()})
		}
	}

	if len(errors) > 0 {
		return ValidationError{Errors: errors}
	}
	return nil
}
