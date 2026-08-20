defmodule TymeslotWeb.Components.CoreComponents.Brand do
  @moduledoc "Brand-related components (logos, marks) extracted from CoreComponents."
  use Phoenix.Component
  use Gettext, backend: TymeslotWeb.Gettext

  @doc """
  Renders the Slate Scheduler logo.

  FORK NOTICE — this file was modified on 2026-08-12.
  See FORK.md for the full patch series.

  Upstream TRADEMARK.md requires a distributed modified version to carry its own
  name and its own logo, so this points at priv/static/images/slate/ rather
  than the upstream marks in priv/static/images/brand/, which are left in place
  and untouched.

  Intrinsic width/height follow the Slate artwork's own viewBox (wordmark
  800x90, icon 500x500), not upstream's 620x200 / 200x200 — reusing those would
  distort the mark.

  ## Attributes
    * `mode` - Either :full (logo + text) or :icon (logo only). Defaults to :full.
    * `class` - Additional CSS classes for the container.
    * `img_class` - Additional CSS classes for the image element.
  """
  attr :mode, :atom, default: :full, values: [:full, :icon]
  attr :class, :string, default: nil
  attr :img_class, :string, default: "h-10"

  @spec logo(map()) :: Phoenix.LiveView.Rendered.t()
  def logo(assigns) do
    ~H"""
    <div class={["flex items-center", @class]}>
      <%= if @mode == :full do %>
        <img
          src="/images/slate/logo-with-text.svg"
          alt="Slate Scheduler"
          width="800"
          height="90"
          class={[@img_class, "w-auto"]}
        />
      <% else %>
        <img
          src="/images/slate/logo.svg"
          alt={dgettext("common", "Slate Scheduler logo")}
          width="500"
          height="500"
          class={[@img_class, "w-auto"]}
        />
      <% end %>
    </div>
    """
  end
end
