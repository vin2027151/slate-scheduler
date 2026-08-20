defmodule TymeslotWeb.Extensions.ParamPalette do
  @moduledoc """
  Slate fork: makes the embed's `data-primary-color` actually take effect.

  Two separate things stopped it working upstream, and both had to be fixed:

    1. The value was discarded server-side. `Context.from_params/2` parsed and
       hex-validated it, then `assign_theme_customization/3` overwrote the
       assign with the database value one line later. Fixed in
       `MountHelpers.restore_param_customizations/2`.

    2. Specificity. The brand palette in `priv/static/css/slate-skin.css`
       is deliberately `:root:root` (0,2,0) so it beats the dashboard-derived
       block that `wrapper.ex` emits as a bare `:root` inside `<body>`. A
       per-request override has to outrank the brand default in turn, so this
       renders at `:root:root:root` (0,3,0).

  The resulting precedence, weakest to strongest, is the one you want:

      dashboard palette (0,1,0)  <  brand skin (0,2,0)  <  ?primary-color= (0,3,0)

  So the page is on-brand by default, and a deliberate per-embed override still
  wins — without the override being able to drag the rest of the palette back
  to the dashboard's dark scheme.

  Rendered through Core's `:theme_extensions` seam, so no template is patched.
  Note that `filter_valid_extensions/1` silently drops a module that fails
  `function_exported?/3` with only a `Logger.warning`, so verify against the
  served HTML rather than assuming.
  """

  use Phoenix.Component

  @hex ~r/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/

  @doc """
  Emits a scoped `<style>` overriding the primary tokens, or nothing at all.

  Receives the full wrapper assigns because that is the extension contract.
  """
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    color = primary_color(assigns[:theme_customization])

    assigns = assign(assigns, :css, color && css_for(color))

    # `Phoenix.HTML.raw/1` matches wrapper.ex's own idiom for emitting into a
    # <style>. It is safe here only because `primary_color/1` has already
    # hex-validated the value — never widen that regex without revisiting this.
    ~H"""
    <style :if={@css} type="text/css">
      <%= Phoenix.HTML.raw(@css) %>
    </style>
    """
  end

  @spec css_for(String.t()) :: String.t()
  defp css_for(color) do
    ":root:root:root{--theme-primary:#{color};--theme-primary-hover:#{darken(color, 0.82)};}"
  end

  # Re-validate at the point of use. The value is already hex-checked in
  # Context.from_params/2, but this interpolates into a raw <style> element, so
  # it does not inherit that guarantee — an unvalidated string here would be a
  # CSS injection. Cheap, and it keeps the guarantee local to the sink.
  @spec primary_color(term()) :: String.t() | nil
  defp primary_color(%{} = customizations) do
    case customizations["primary_color"] do
      value when is_binary(value) -> if Regex.match?(@hex, value), do: value
      _other -> nil
    end
  end

  defp primary_color(_other), do: nil

  # Hover state, derived rather than configured: the embed exposes one colour,
  # and a hover that is simply the same colour reads as a dead control.
  @spec darken(String.t(), float()) :: String.t()
  defp darken("#" <> hex, factor) do
    hex = if byte_size(hex) == 3, do: expand(hex), else: hex

    hex
    |> String.to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.map_join(fn pair ->
      pair
      |> List.to_string()
      |> String.to_integer(16)
      |> then(&min(255, round(&1 * factor)))
      |> Integer.to_string(16)
      |> String.pad_leading(2, "0")
    end)
    |> then(&("#" <> &1))
  end

  @spec expand(String.t()) :: String.t()
  defp expand(<<r::binary-1, g::binary-1, b::binary-1>>), do: r <> r <> g <> g <> b <> b
end
