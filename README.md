# Shop API

A small coffee and tea shop backend. Rails 8 API-only app with PostgreSQL, Devise and JWT authentication, and two roles (`user` and `admin`).

- Users sign up and log in, search items, place orders and view their own order history.
- A user can edit only their own profile.
- An admin can view and edit users and items.

## Tech stack

- Ruby 3.4.11 (see `.ruby-version`), Rails 8.1 (API mode)
- PostgreSQL 16
- Devise + devise-jwt (token in the `Authorization` header)
- Minitest and RuboCop, both run in CI (GitHub Actions)

## Quick start with Docker (recommended)

You only need [Docker](https://docs.docker.com/get-docker/) (Docker Desktop on Windows and macOS). You do not need Ruby or PostgreSQL on your machine.

```bash
git clone https://github.com/tvk777/shop-api.git shop-api
cd shop-api
docker compose up --build
```

The first build can take 5-15 minutes, depending on your connection. When you see `Listening on http://0.0.0.0:3000`, the API is available at `http://localhost:3000`.

On start the app creates the database, runs migrations and loads seed data (30 coffee and tea items and two test accounts). Seeds are safe to run again.

Useful commands:

```bash
docker compose run --rm web bin/rails test      # run the tests
docker compose run --rm web bin/rubocop         # run the linter
docker compose run --rm web bin/rails console   # Rails console
docker compose down                             # stop the containers, keep the data
docker compose down -v                          # stop and delete the database volume
```

On Windows, run Docker from a WSL2 terminal and keep the project inside the WSL file system (for example `~/projects`), not under `/mnt/c`. Otherwise everything is very slow.

Verified on: Windows 11 with WSL2 and macOS.

## Run without Docker

You need Ruby (the version in `.ruby-version`), PostgreSQL 16 and the PostgreSQL client headers (`libpq`).

### 1. Install the system packages

**Ubuntu / Debian**

```bash
sudo apt update
sudo apt install -y build-essential git curl libssl-dev libyaml-dev zlib1g-dev libffi-dev libreadline-dev libpq-dev
```

**macOS (Homebrew)**

```bash
brew install rbenv ruby-build libpq
```

`libpq` is keg-only on macOS, so tell Bundler where to find it before installing gems:

```bash
bundle config build.pg --with-pg-config="$(brew --prefix libpq)/bin/pg_config"
```

**Windows**

Install WSL2 with Ubuntu and Docker Desktop with WSL integration enabled, then follow the Ubuntu steps inside the WSL terminal.

### 2. Install Ruby with rbenv

```bash
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc
source ~/.bashrc
rbenv install 3.4.11
rbenv global 3.4.11
```

On macOS with Homebrew, `rbenv` and `ruby-build` are already installed, so run only the `rbenv init` line for your shell (zsh uses `~/.zshrc` and `eval "$(rbenv init - zsh)"`) and the last two commands.

### 3. Start PostgreSQL

The simplest way on any system is a container:

```bash
docker run -d --name shop-db \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  -v shop-pgdata:/var/lib/postgresql/data \
  postgres:16
```

If you already have PostgreSQL installed, point the app at it with the environment variables below.

### 4. Set up and run the app

```bash
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

The API is available at `http://localhost:3000`.

```bash
bin/rails test
bin/rubocop
```

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_USER` | `postgres` | PostgreSQL user |
| `DB_PASSWORD` | `postgres` | PostgreSQL password |
| `CORS_ORIGINS` | `http://localhost:5173` | Allowed frontend origins, comma-separated |

## Deploy on Render

Free plan, native Ruby runtime, one Render Postgres database. Create the database first, then a Web Service from this repository.

| Setting | Value |
| --- | --- |
| Build command | `./bin/render-build.sh` (bundle install, `db:migrate`, `db:seed`) |
| Start command | `bin/rails server` |
| Health check path | `/up` |

The free plan has no pre-deploy command or shell, so migrations and seeds run in the build script. Seeds are idempotent. They create two accounts for reviewing the deployed app: a public demo user (`user@example.com`, password `password123`) and an admin (`admin@example.com`) whose password comes from `SEED_ADMIN_PASSWORD`. The build fails in production if that variable is missing.

Environment variables:

| Variable | Value |
| --- | --- |
| `DATABASE_URL` | Internal connection URL of the Render database |
| `RAILS_MASTER_KEY` | Contents of `config/master.key` (also used as the JWT secret through `secret_key_base`) |
| `WEB_CONCURRENCY` | Puma workers, for example `1` on the free instance (512 MB RAM) |
| `CORS_ORIGINS` | The frontend URL, for example `https://your-app.vercel.app` (comma-separated for several) |
| `SEED_ADMIN_PASSWORD` | Required in production. Password of `admin@example.com`, used only when the seeds create the account; an existing admin is not changed |

Production uses a single database, an in-memory cache store and the `:async` Active Job and Action Cable adapters, because the app has no jobs, channels or caching.

Free plan limits: the web service sleeps after a period of inactivity, so the first request can take up to a minute. The free database expires after 30 days.

## Test accounts

Created by the seeds:

| Email | Password | Role |
| --- | --- | --- |
| `admin@example.com` | `password123` (local development only) | admin |
| `user@example.com` | `password123` | user |

On the deployed app the admin password is not published here; it is provided to reviewers separately.

## Authentication

Sign up or log in, then send the token from the `Authorization` response header with every request.

```bash
# Log in and print the response headers
curl -si -X POST http://localhost:3000/login \
  -H "Content-Type: application/json" \
  -d '{"user":{"email":"user@example.com","password":"password123"}}'

# Use the token (the part after "Bearer ")
curl -s http://localhost:3000/items?q=ethiopia \
  -H "Authorization: Bearer <token>"
```

Status codes: `401` means no valid token, `403` means the user's role is not allowed, `404` is also returned for another user's order, `422` means validation errors (`{"errors": [...]}`), and `400` means malformed parameters.

## API overview

| Method and path | Description | Access |
| --- | --- | --- |
| `POST /signup` | Register (role is always `user`) | public |
| `POST /login` | Log in, returns the JWT in `Authorization` | public |
| `DELETE /logout` | Log out and revoke the token | any user |
| `GET /items?q=` | List items, optional search by name or description | any user |
| `GET /profile` | Own profile | any user |
| `PATCH /profile` | Edit own data (changing the password requires `current_password`; `role` is ignored) | any user |
| `POST /orders` | Place an order | user |
| `GET /orders` | Own orders with their items | user |
| `GET /orders/:id` | One own order | user |
| `GET /admin/users`, `GET /admin/users/:id`, `PATCH /admin/users/:id` | View and edit users, including `role`; `GET` responses include `orders_count` | admin |
| `DELETE /admin/users/:id` | Delete a user together with all their orders (items are kept); you cannot delete yourself or the last admin (`422`) | admin |
| `GET`, `POST /admin/items`, `GET`, `PATCH`, `DELETE /admin/items/:id` | Manage items | admin |

`GET /admin/users` and `GET /admin/users/:id` add `orders_count` (the number of the user's orders) to each user; the login, signup and profile responses do not include it.

Admins get `403` with `{"errors":["Admins cannot place or view orders"]}` on all `/orders` endpoints.

Place an order:

```json
POST /orders
{ "order": { "items": [ { "item_id": 2, "quantity": 2 }, { "item_id": 5, "quantity": 1 } ] } }
```

The server takes prices from the database and calculates the total. The order and its lines are saved in one transaction.

`item_id` and `quantity` must be whole numbers (a JSON integer or a string of digits). Malformed values such as `"2.7"` or `"12junk"`, and an order total above 99,999,999.99, return `422`. A non-string `q` on `GET /items` or `GET /admin/items` (for example `q[]=x`) returns `400` with `{"errors":["Invalid search parameter"]}`.

## Database

Four tables, as in the task specification:

- `users` (first name, last name, email, password, role)
- `items` (name, description, price)
- `orders` (`user_id`, amount)
- `orders_description` (`order_id`, `item_id`, quantity)

One column was added to the specification: `orders_description.unit_price`. It stores the price paid for each line, so changing an item's price later does not change past orders. The task author confirmed that adding columns is allowed.

Database check constraints back up the model validations (`quantity BETWEEN 1 AND 99`, `unit_price >= 0`, `items.price >= 0`, `orders.amount >= 0`).

Item prices go from 0 to 99,999,999.99 (the `decimal(10,2)` column), checked in the frontend and the backend.

Each order line accepts a quantity from 1 to 99. This is a simple safety limit against typos and oversized orders, enforced in both the frontend and the backend. The task has no stock data, so the limit is fixed. In a real shop it would come from the item's available stock (a `stock` column on `items`, checked when the order is placed and decreased inside the same transaction).
