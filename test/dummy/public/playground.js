document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy-json]")
  if (!button) return

  const viewer = button.closest("[data-json-viewer]")
  const pre = viewer && viewer.querySelector("pre")
  if (!pre) return

  const originalLabel = button.dataset.label || button.textContent || "Copy"

  try {
    await navigator.clipboard.writeText(pre.textContent || "")
    button.textContent = button.dataset.copiedLabel || "Copied!"
  } catch (error) {
    button.textContent = "Copy failed"
  }

  button.disabled = true
  window.setTimeout(() => {
    button.textContent = originalLabel
    button.disabled = false
  }, 1500)
})

document.addEventListener("change", (event) => {
  const field = event.target.closest("[data-autosubmit-setting]")
  if (!field || !field.form) return

  const initialValue = field.dataset.initialValue ?? ""
  const currentValue = field.value ?? ""
  if (currentValue === initialValue) return

  field.form.requestSubmit()
})
