package product

import (
	"net/http"

	genproduct "open-shop-webserver/gen/product"
)

type ProductHandler struct{}

var _ genproduct.ServerInterface = (*ProductHandler)(nil)

func NewProductHandler() *ProductHandler {
	return &ProductHandler{}
}

func (h *ProductHandler) ClearCart(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetCart(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) AddCartItem(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) RemoveCartItem(w http.ResponseWriter, r *http.Request, itemId genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) UpdateCartItem(w http.ResponseWriter, r *http.Request, itemId genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) ListCategories(w http.ResponseWriter, r *http.Request, params genproduct.ListCategoriesParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetCategory(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetCategoryProducts(w http.ResponseWriter, r *http.Request, id genproduct.ID, params genproduct.GetCategoryProductsParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) ListOrders(w http.ResponseWriter, r *http.Request, params genproduct.ListOrdersParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) CreateOrder(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetOrder(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) CancelOrder(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) UpdateOrderPayment(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) ConfirmOrderPayment(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) ListProducts(w http.ResponseWriter, r *http.Request, params genproduct.ListProductsParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) SearchProducts(w http.ResponseWriter, r *http.Request, params genproduct.SearchProductsParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetProduct(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetProductReviews(w http.ResponseWriter, r *http.Request, id genproduct.ID, params genproduct.GetProductReviewsParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) AddProductReview(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) DeleteReview(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) UpdateReview(w http.ResponseWriter, r *http.Request, id genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) GetWishlist(w http.ResponseWriter, r *http.Request, params genproduct.GetWishlistParams) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) AddWishlistItem(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}

func (h *ProductHandler) RemoveWishlistItem(w http.ResponseWriter, r *http.Request, itemId genproduct.ID) {
	http.Error(w, "not implemented", http.StatusNotImplemented)
}
