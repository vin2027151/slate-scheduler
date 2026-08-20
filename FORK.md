# FORK.md — Slate Scheduler

Fork of [Tymeslot](https://github.com/Tymeslot/tymeslot), AGPL-3.0-or-later.
Own name and own logo per upstream `TRADEMARK.md`; not affiliated with or
endorsed by the Tymeslot project. See `NOTICE`.

This file is the rebase manifest. Its job is to make an upstream bump mechanical:
everything in §2 must be re-applied, everything in §3 can be ignored, and §4 is
what breaks *without* conflicting.

---

## 1. Base pin

| | |
|---|---|
| upstream tag | `v1.8.1` |
| upstream sha | `591afe69286894541bf55bd46dfb62549413735e` |
| forked | 2026-08-12 |
| fork revision | `rp.1` → image `ghcr.io/vin2027151/slate-scheduler:1.8.1-rp.1` |

Branches: `vendor` (pristine, always exactly an upstream tag) · `main`
(= `vendor` + the patch series below) · `rebase/vX.Y.Z` (throwaway).
**Rebase, never merge** — the value is that `git log vendor..main` prints the
entire fork as a short, readable series.

```bash
git config remote.upstream.fetch "+refs/tags/*:refs/tags/upstream/*"
```

**Deploy tags use the `deploy/` prefix, never `v*`.** Upstream's
`.github/workflows/docker-publish.yml` triggers on `push: tags: ['v*']`, its
`github.server_url` guard passes on a fork, and it would either fail on missing
Docker Hub secrets or attempt to push to `luka1thb/tymeslot` — someone else's
namespace. Disable that workflow in the Actions UI (a repository setting, so it
survives every rebase and stays invisible in `git diff`) rather than deleting
the file.

**Never touch `version:` in `mix.exs`.** Upstream rewrites that line every
release; claiming it guarantees a conflict every time for no benefit. The fork
revision lives in the image tag.

---

## 2. Modified upstream files — the whole patch surface

Five files. Re-apply every one on a rebase.

| file | change | if the patch is lost |
|---|---|---|
| `config/config.exs` | `scheduling_additional_css: ["/css/slate-skin.css?v=N"]` and `theme_extensions: [SourceOffer, ParamPalette]` | **silent** — page renders stock Rhythm emerald, and the AGPL source offer disappears |
| `Dockerfile.docker` | `ARG PG_MAJOR=17`, pinning `postgresql-17` in the **`release`** stage (not `release-slim`) | **silent until a base bump**, then a production crash loop: PG refuses an incompatible cluster, `start-docker.sh` exits 1, `restart: unless-stopped` loops |
| `lib/tymeslot_web/components/layouts/scheduling_root.html.heex` | title suffix, `og:site_name`, favicon → `/images/slate/favicon.svg` | cosmetic, but reverts the product name to Tymeslot — a **trademark** issue, not just a branding one |
| `lib/tymeslot_web/themes/core/mount_helpers.ex` | `restore_param_customizations/2` — stops `assign_theme_customization/3` clobbering the hex-validated `?primary-color=` that `Context.from_params/2` just parsed | **silent** — `data-primary-color` goes back to doing nothing at all, while embed.js still forwards it and the dashboard still offers it |
| `priv/static/fonts/`, `priv/static/css/`, `priv/static/images/slate/` | new directories (see §3) | — |

Both `config/config.exs` edits sit on upstream's own extension seams
(`scheduling_additional_css`, `theme_extensions`), which exist precisely so an
external layer can inject CSS and UI. That is why the patch surface is this
small and not a new theme.

---

## 3. Additive-only paths — never conflict, do not audit on rebase

```
priv/static/css/slate-skin.css          the brand skin
priv/static/fonts/{instrument-sans,newsreader}.woff2 + OFL.txt
priv/static/images/slate/{favicon,logo,logo-with-text}.svg
lib/tymeslot_web/extensions/source_offer.ex
lib/tymeslot_web/extensions/param_palette.ex
FORK.md  NOTICE  .github/workflows/fork-image.yml
```

Assets are **added**, never overwritten in place. `priv/static/images/brand/`
keeps upstream's files untouched: a modified binary is invisible in `git diff`,
and a new path is self-documenting.

---

## 4. Upstream contracts the fork depends on — the silent-breakage watch list

These fail **without** producing a merge conflict. Diff them on every bump.

| what | why it matters |
|---|---|
| `scheduling_root.html.heex` lines 37–43 | the `render_theme_css/1` call followed by the `scheduling_additional_css` loop. The skin only wins because it is linked **after** the theme sheet. If upstream reorders these, the cascade inverts. |
| `helpers.ex` `assign_theme_customization/3` | the function whose clobbering we undo. If upstream ever fixes this themselves, `restore_param_customizations/2` becomes a harmless no-op — but if they change the assign KEY, our merge silently stops applying. |
| `layouts.ex` `render_theme_extensions/1` | the source-offer and param-palette seam. `filter_valid_extensions/1` silently drops a module that fails `function_exported?/3`, logging only a warning. |
| `rhythm/scheduling/wrapper.ex` | the only caller of `render_theme_extensions/1`, and the emitter of the generated `:root` palette block. |
| the compiled Rhythm class vocabulary | the skin targets `.scheduling-box`, `.input`, `.custom-question-*`, `.success-badge-inner*`, `.action-button-*`, `.awaiting-payment-*`, `.glass-morphism-card`, `.timezone-dropdown`. A renamed class silently stops being styled. |
| `Dockerfile.docker` runtime base | a move off `debian:trixie-slim` changes the available PostgreSQL major. The pin turns that into a build failure — which is the point. |
| `start-docker.sh` | migrations run unconditionally on start; the PGDATA layout migration; the "empty `DATA_ENCRYPTION_KEY` is only a warning" behaviour. |
| `priv/repo/migrations/` | **the rollback contract.** `Ecto.Migrator` runs `:up` only, so reverting an image does not revert a schema. Rollback is free *only* while the fork adds no migrations and no upstream migration has been taken. |
| `LICENSE`, `COPYRIGHT` | the CLA lets upstream relicense. See §5 step 1. |

---

## 5. Rebase runbook

1. `git fetch upstream --tags`
2. **`git diff upstream/vOLD..upstream/vNEW -- LICENSE COPYRIGHT`**
   *If it is no longer AGPL-3.0, STOP.* Do not rebase. Upstream's CLA permits
   relicensing, exactly as Cal.com did; code already taken stays AGPL, but
   future versions may not be mergeable.
3. `git diff upstream/vOLD..upstream/vNEW -- <every path in §2 and §4>`
4. `git diff --stat upstream/vOLD..upstream/vNEW -- priv/repo/migrations/`
   Any new migration means rollback is no longer free — treat it as a different
   class of change: fresh backup, longer window, know the down path first.
5. `git checkout -b rebase/vNEW main && git rebase --onto upstream/vNEW upstream/vOLD rebase/vNEW`
6. `mix deps.get && mix assets.build && mix test`
7. Manual QA — there is no visual regression suite:
   overview → schedule → custom questions → booking → confirmation, at 375px and
   1280px, **embedded in a local copy of the contact page**, then cancel and
   reschedule from the confirmation email.
8. Verify the skin actually applied (not just that the page loads):
   ```bash
   curl -sS https://the booking host/vincent | grep -o 'slate-skin[^"]*'
   curl -sS https://the booking host/vincent | grep -o 'source-offer'
   ```
9. Fast-forward `main`, tag `deploy/<version>-rp.<n>`, let CI push, then deploy.

**Cadence: batch monthly, except security advisories, which go within 7 days.**
A public repo plus skip-most-releases is not a coherent pair.

---

## 6. Rollback

```bash
ssh … 'cd /opt/tymeslot && cp docker-compose.yml.prev docker-compose.yml \
        && docker compose up -d --wait --wait-timeout 90'
```

~40 seconds, no network — the previous image stays on disk, so never prune
before a cutover. This is clean **because the fork adds zero migrations** and
never changes `booking_theme` in the database. Both conditions are checked in
§5; if either stops holding, this section is wrong.

---

## 7. Things that look like bugs and are not

- **`!important` throughout `slate-skin.css`.** Measured, not lazy. Rhythm
  targets these elements with `html.rhythm-theme[data-embedded] .foo` (0,3,1),
  and `.input` has no bare selector at all. A bare class loses; a
  specificity-matching prefix would break the next time upstream adds a compound
  selector. `!important` is also the only thing that beats the inline
  `style="background-color: …"` on `.video-background-container` and the inline
  `style="color: white"` in `error_component.ex`.
- **`:root:root` on the token block.** The dashboard palette is emitted as a
  bare `:root` inside `<body>`, i.e. *after* this stylesheet in `<head>`, so an
  equal-specificity block would lose on source order. The generated block cannot
  be emptied (a nil customization is replaced by a fallback) and cannot be made
  light (`PaletteDerivation` hardcodes background L=8%), so specificity is the
  only lever.
- **Three levels of `:root`, and they are all deliberate.** The cascade is
  `dashboard palette (0,1,0) < brand skin :root:root (0,2,0) < ?primary-color=
  :root:root:root (0,3,0)`. Verified in a browser, not assumed. The page is
  on-brand by default, a per-embed override still wins, and an override cannot
  drag the rest of the palette back to the dashboard's dark scheme.
- **The skin lives in `priv/static/css/`, not `priv/static/assets/`.**
  `Dockerfile.docker` runs `rm -rf priv/static/assets/` after `COPY`, so a
  stylesheet there works locally and vanishes from the image.
- **`?v=` in the config path.** The `<link>` href is rendered verbatim rather
  than through `~p`, so it is not digest-resolved and is cached for an hour.
  Bump `?v=` on every skin edit.
