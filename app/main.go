package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

type application struct {
	db      *sql.DB
	started time.Time
}

func getenv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func dsn() string {
	return fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=%s",
		getenv("DB_HOST", "postgres"),
		getenv("DB_PORT", "5432"),
		getenv("DB_USER", "demo"),
		os.Getenv("DB_PASSWORD"),
		getenv("DB_NAME", "demo"),
		getenv("DB_SSLMODE", "disable"),
	)
}

func waitForDB(ctx context.Context) (*sql.DB, error) {
	db, err := sql.Open("postgres", dsn())
	if err != nil {
		return nil, err
	}

	deadline := time.Now().Add(5 * time.Minute)
	for {
		pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
		err = db.PingContext(pingCtx)
		cancel()
		if err == nil {
			return db, nil
		}
		if time.Now().After(deadline) {
			return nil, fmt.Errorf("database did not become ready in time: %w", err)
		}
		log.Printf("waiting for database: %v", err)
		time.Sleep(5 * time.Second)
	}
}

func migrate(db *sql.DB) error {
	_, err := db.Exec(`
		CREATE TABLE IF NOT EXISTS messages (
			id SERIAL PRIMARY KEY,
			body TEXT NOT NULL
		)
	`)
	if err != nil {
		return err
	}

	var count int
	if err := db.QueryRow(`SELECT COUNT(*) FROM messages`).Scan(&count); err != nil {
		return err
	}

	if count == 0 {
		_, err = db.Exec(
			`INSERT INTO messages (body) VALUES ($1), ($2)`,
			"hello from PostgreSQL running inside K3s",
			fmt.Sprintf("seeded at %s", time.Now().UTC().Format(time.RFC3339)),
		)
		if err != nil {
			return err
		}
	}

	return nil
}

func (a *application) healthz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()

	if err := a.db.PingContext(ctx); err != nil {
		http.Error(w, fmt.Sprintf("db not ready: %v", err), http.StatusServiceUnavailable)
		return
	}

	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok\n"))
}

func (a *application) index(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	rows, err := a.db.QueryContext(ctx, `SELECT id, body FROM messages ORDER BY id ASC`)
	if err != nil {
		http.Error(w, fmt.Sprintf("query failed: %v", err), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	hostname, _ := os.Hostname()
	var b strings.Builder
	b.WriteString("demo-go-app on K3s\n")
	b.WriteString(fmt.Sprintf("hostname: %s\n", hostname))
	b.WriteString(fmt.Sprintf("uptime: %s\n", time.Since(a.started).Round(time.Second)))
	b.WriteString("messages:\n")

	for rows.Next() {
		var id int
		var body string
		if err := rows.Scan(&id, &body); err != nil {
			http.Error(w, fmt.Sprintf("scan failed: %v", err), http.StatusInternalServerError)
			return
		}
		b.WriteString(fmt.Sprintf("- [%d] %s\n", id, body))
	}
	if err := rows.Err(); err != nil {
		http.Error(w, fmt.Sprintf("rows failed: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write([]byte(b.String()))
}

func main() {
	ctx := context.Background()
	db, err := waitForDB(ctx)
	if err != nil {
		log.Fatalf("database startup failed: %v", err)
	}

	if err := migrate(db); err != nil {
		log.Fatalf("database migration failed: %v", err)
	}

	app := &application{db: db, started: time.Now()}

	mux := http.NewServeMux()
	mux.HandleFunc("/", app.index)
	mux.HandleFunc("/healthz", app.healthz)

	server := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Printf("starting server on %s", server.Addr)
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("server failed: %v", err)
	}
}
