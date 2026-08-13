defmodule TymeslotWeb.Extensions.SourceOffer do
  @moduledoc """
  Slate fork: the AGPL-3.0 section 13 source offer.

  Section 13 requires that anyone who interacts with a *modified* version of the
  program remotely over a network be offered the Corresponding Source of that
  modified version. The booking page is public, so its visitors are exactly
  those users — which is why this renders inside the booking flow (and therefore
  inside the embedded iframe) rather than only on the marketing site.

  Wired up through Core's own extension seam rather than by patching a template:

      config :tymeslot, theme_extensions: [{TymeslotWeb.Extensions.SourceOffer, :render}]

  `TymeslotWeb.Layouts.render_theme_extensions/1` applies each `{mod, func}` to
  the layout assigns, and the theme wrapper calls it. Two consequences worth
  knowing:

    * `filter_valid_extensions/1` silently drops any entry failing
      `Code.ensure_loaded?/1` or `function_exported?/3`, logging only a warning.
      A typo here makes the notice vanish with no visible signal, so the deploy
      checklist greps the served HTML for `source-offer`.

    * The wrapper is not rendered by the payment-return pages, so the offer does
      not appear there. The booking flow is the surface that matters for section
      13, and the marketing site's legal pages carry the offer in prose as well.

  Deliberately links the repository root, not a tag or commit. A version-pinned
  URL rendered on a public page publishes exactly which release is running, and
  the fork's stated policy is to batch upstream releases rather than take every
  one — advertising the gap is not worth the precision.

  Styling lives in `priv/static/css/slate-skin.css` under `.source-offer`. It
  must stay visible: AGPL says "prominently", so no `display: none`, no
  zero-opacity, and nothing that only appears on hover.
  """

  use Phoenix.Component
  use Gettext, backend: TymeslotWeb.Gettext

  @repo_url "https://github.com/vin2027151/slate-scheduler"

  @doc """
  Renders the source-offer link.

  Receives the full layout assigns because that is the extension contract; none
  of them are read, so this is safe on every page the wrapper renders.
  """
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns = assign_new(assigns, :repo_url, fn -> @repo_url end)

    ~H"""
    <a class="source-offer" href={@repo_url} target="_blank" rel="noopener noreferrer">
      {dgettext("booking", "Source")}
    </a>
    """
  end
end
