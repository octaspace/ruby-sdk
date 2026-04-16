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

// Page loader: appears only after 400 ms of waiting, so fast responses do not flash.
const LOADER_SKIP = ["/playground/settings", "/playground/request-log"]
const LOADER_DELAY_MS = 400
let loaderTimer = null

const activateLoader = () => {
  const element = document.getElementById("page-loader")
  if (!element) return

  element.classList.add("loader-active")
  element.setAttribute("aria-hidden", "false")
}

const scheduleLoader = () => {
  if (loaderTimer !== null) return

  loaderTimer = window.setTimeout(() => {
    loaderTimer = null
    activateLoader()
  }, LOADER_DELAY_MS)
}

const hideLoader = () => {
  if (loaderTimer !== null) {
    window.clearTimeout(loaderTimer)
    loaderTimer = null
  }

  const element = document.getElementById("page-loader")
  if (!element) return

  element.classList.remove("loader-active")
  element.setAttribute("aria-hidden", "true")
}

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!form || !form.action) return

  try {
    const pathname = new URL(form.action, window.location.href).pathname
    if (LOADER_SKIP.some((value) => pathname === value)) return
  } catch (_error) {
    return
  }

  scheduleLoader()
})

document.addEventListener("click", (event) => {
  if (!event.target.closest("[data-scroll-target]")) {
    if (!(event.metaKey || event.ctrlKey || event.shiftKey || event.altKey)) {
      const link = event.target.closest("a[href]")

      if (link) {
        const href = link.getAttribute("href")

        if (href && !href.startsWith("#") && !href.startsWith("mailto:") && link.target !== "_blank") {
          try {
            const url = new URL(href, window.location.href)
            if (url.origin === window.location.origin) {
              scheduleLoader()
            }
          } catch (_error) {
          }
        }
      }
    }
  }

  const trigger = event.target.closest("[data-scroll-target]")
  if (!trigger) return

  const targetId = trigger.dataset.scrollTarget
  if (!targetId) return

  const target = document.getElementById(targetId)
  if (!target) return

  event.preventDefault()
  target.scrollIntoView({behavior: "smooth", block: "start"})

  if (typeof target.focus === "function") {
    target.focus({preventScroll: true})
  }
})

const syncDiagnosticsSelection = () => {
  const list = document.querySelector("[data-diagnostics-list]")
  const selected = document.querySelector("[data-diagnostics-item][data-selected='true']")
  if (!list || !selected) return

  window.requestAnimationFrame(() => {
    selected.scrollIntoView({block: "nearest", inline: "nearest"})
  })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", syncDiagnosticsSelection, {once: true})
} else {
  syncDiagnosticsSelection()
}

window.addEventListener("pageshow", (event) => {
  if (event.persisted) {
    hideLoader()
  }
})

window.addEventListener("pagehide", hideLoader)
