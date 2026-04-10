/* SES Dashboard — vanilla JS, no framework required */

(function () {
  "use strict";

  // ── Chart initialisation ─────────────────────────────────────────────
  function initChart() {
    var el = document.getElementById("chart-data");
    var canvas = document.getElementById("activity-chart");
    if (!el || !canvas || typeof Chart === "undefined") return;

    var data;
    try { data = JSON.parse(el.textContent); } catch (e) { return; }

    new Chart(canvas.getContext("2d"), {
      type: "line",
      data: {
        labels: data.labels,
        datasets: [{
          label: "Emails sent",
          data: data.data,
          borderColor: "#0d6efd",
          backgroundColor: "rgba(13,110,253,.08)",
          borderWidth: 2,
          pointRadius: 3,
          fill: true,
          tension: 0.3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: { display: false },
          tooltip: { mode: "index", intersect: false }
        },
        scales: {
          x: { grid: { display: false } },
          y: { beginAtZero: true, ticks: { precision: 0 } }
        }
      }
    });
  }

  // ── Copy to clipboard ────────────────────────────────────────────────
  function copyToClipboard(text) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text).catch(function () {
        fallbackCopy(text);
      });
    } else {
      fallbackCopy(text);
    }
  }

  function fallbackCopy(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.style.position = "fixed";
    ta.style.opacity = "0";
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try { document.execCommand("copy"); } catch (e) { /* ignore */ }
    document.body.removeChild(ta);
  }

  // ── Copy buttons ─────────────────────────────────────────────────────
  function initCopyButtons() {
    document.querySelectorAll("[data-copy]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var text = btn.getAttribute("data-copy");
        copyToClipboard(text);
        var original = btn.textContent;
        btn.textContent = "Copied!";
        setTimeout(function () { btn.textContent = original; }, 1500);
      });
    });
  }

  // ── Event raw data toggles ───────────────────────────────────────────
  function initEventToggles() {
    document.querySelectorAll(".event-data-toggle").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var raw = btn.closest(".event-item").querySelector(".event-raw");
        if (!raw) return;
        raw.classList.toggle("visible");
        btn.textContent = raw.classList.contains("visible") ? "Hide raw" : "Show raw";
      });
    });
  }

  // ── Filter form reset ─────────────────────────────────────────────────
  function initFilterReset() {
    var resetBtn = document.getElementById("filter-reset");
    if (!resetBtn) return;
    resetBtn.addEventListener("click", function () {
      var form = resetBtn.closest("form");
      if (!form) return;
      form.querySelectorAll("input[type=text], input[type=date], select").forEach(function (el) {
        el.value = "";
      });
      form.submit();
    });
  }

  // ── Confirm destructive actions ───────────────────────────────────────
  function initConfirmLinks() {
    document.querySelectorAll("[data-confirm]").forEach(function (el) {
      el.addEventListener("click", function (e) {
        if (!window.confirm(el.getAttribute("data-confirm"))) {
          e.preventDefault();
        }
      });
    });
  }

  // ── Boot ─────────────────────────────────────────────────────────────
  document.addEventListener("DOMContentLoaded", function () {
    initChart();
    initCopyButtons();
    initEventToggles();
    initFilterReset();
    initConfirmLinks();
  });
})();
