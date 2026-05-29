package api

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/locationshare/backend/internal/config"
	"github.com/locationshare/backend/internal/service"
)

// NewRouter wires all handlers and returns a ready-to-serve http.Handler.
func NewRouter(
	cfg *config.Config,
	authSvc *service.AuthService,
	userSvc *service.UserService,
	locSvc *service.LocationService,
	groupSvc *service.GroupService,
) http.Handler {
	r := chi.NewRouter()

	r.Use(chimiddleware.Recoverer)
	r.Use(chimiddleware.RealIP)
	r.Use(CORSMiddleware)

	ah := &authHandler{svc: authSvc}
	uh := &userHandler{svc: userSvc}
	lh := &locationHandler{svc: locSvc}
	gh := &groupHandler{svc: groupSvc}

	jwtAuth := AuthMiddleware(cfg)

	r.Get("/api/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "UP"})
	})

	// Auth — most endpoints are public; logout-all and change-password require auth.
	r.Route("/api/auth", func(r chi.Router) {
		r.Post("/register", ah.register)
		r.Post("/login", ah.login)
		r.Post("/refresh", ah.refresh)
		r.Post("/logout", ah.logout)

		r.Group(func(r chi.Router) {
			r.Use(jwtAuth)
			r.Post("/logout-all", ah.logoutAll)
			r.Post("/change-password", ah.changePassword)
		})
	})

	// User — all protected.
	r.Route("/api/users", func(r chi.Router) {
		r.Use(jwtAuth)
		r.Get("/me", uh.me)
		r.Patch("/me", uh.updateMe)
	})

	// Groups — all protected.
	r.Route("/api/groups", func(r chi.Router) {
		r.Use(jwtAuth)
		r.Post("/", gh.create)
		r.Get("/", gh.list)
		r.Post("/join", gh.join)

		r.Route("/{groupId}", func(r chi.Router) {
			r.Get("/", gh.detail)
			r.Patch("/", gh.update)
			r.Delete("/", gh.delete)
			r.Delete("/leave", gh.leave)
			r.Post("/kick/{userId}", gh.kick)
			r.Post("/regenerate-code", gh.regenerateCode)

			// Location sub-routes
			r.Get("/locations", lh.list)
			r.Put("/locations/me", lh.upsert)
		})
	})

	return r
}
