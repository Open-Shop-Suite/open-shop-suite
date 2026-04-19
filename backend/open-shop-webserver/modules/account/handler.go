package account

import (
	"net/http"

	genaccount "open-shop-webserver/gen/account"
)

type AccountHandler struct{}

var _ genaccount.ServerInterface = (*AccountHandler)(nil)

func NewAccountHandler() *AccountHandler {
	return &AccountHandler{}
}

func (h *AccountHandler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) LoginCustomer(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) LogoutCustomer(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) GetOAuthAuthorizationUrl(w http.ResponseWriter, r *http.Request, provider genaccount.GetOAuthAuthorizationUrlParamsProvider, params genaccount.GetOAuthAuthorizationUrlParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) HandleOAuthCallback(w http.ResponseWriter, r *http.Request, provider genaccount.HandleOAuthCallbackParamsProvider) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) ForgotPassword(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) ResetPassword(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) RefreshToken(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) ResendEmailVerification(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) RevokeOtherSessions(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) ListSessions(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) RevokeSession(w http.ResponseWriter, r *http.Request, id genaccount.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) RegisterCustomer(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) VerifyEmail(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) DeleteMyAccount(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) GetMyProfile(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) UpdateMyProfile(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) GetCustomerAddresses(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) AddCustomerAddress(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) DeleteCustomerAddress(w http.ResponseWriter, r *http.Request, addressId string) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) UpdateCustomerAddress(w http.ResponseWriter, r *http.Request, addressId string) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *AccountHandler) SetDefaultAddress(w http.ResponseWriter, r *http.Request, addressId string) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}
