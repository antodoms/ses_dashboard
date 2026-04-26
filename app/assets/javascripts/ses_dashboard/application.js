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

  // ── Webhook Forwards builder ──────────────────────────────────────────
  var WF_FIELDS = [
    { value: "event_type",  label: "Event Type" },
    { value: "source",      label: "From (source)" },
    { value: "destination", label: "To (destination)" },
    { value: "subject",     label: "Subject" }
  ];

  var WF_OPERATORS = [
    { value: "in",          label: "is in" },
    { value: "not_in",      label: "is not in" },
    { value: "eq",          label: "equals" },
    { value: "not_eq",      label: "does not equal" },
    { value: "starts_with", label: "starts with" },
    { value: "ends_with",   label: "ends with" },
    { value: "contains",    label: "contains" }
  ];

  var WF_EVENT_TYPES = [
    "send", "delivery", "bounce", "complaint", "open", "click", "reject", "rendering_failure"
  ];

  function wfBuildSelect(options, selected, className) {
    var sel = document.createElement("select");
    sel.className = "form-control " + className;
    options.forEach(function (opt) {
      var o = document.createElement("option");
      o.value = opt.value;
      o.textContent = opt.label;
      if (opt.value === selected) o.selected = true;
      sel.appendChild(o);
    });
    return sel;
  }

  function wfBuildCheckboxes(selected) {
    var wrap = document.createElement("div");
    wrap.className = "wf-checkboxes";
    var selectedArr = Array.isArray(selected) ? selected : [];
    WF_EVENT_TYPES.forEach(function (et) {
      var label = document.createElement("label");
      label.className = "wf-checkbox-label";
      var cb = document.createElement("input");
      cb.type = "checkbox";
      cb.value = et;
      cb.className = "wf-event-cb";
      if (selectedArr.indexOf(et) !== -1) cb.checked = true;
      label.appendChild(cb);
      label.appendChild(document.createTextNode(" " + et));
      wrap.appendChild(label);
    });
    return wrap;
  }

  function wfBuildTextInput(value, placeholder) {
    var input = document.createElement("input");
    input.type = "text";
    input.className = "form-control wf-value";
    input.placeholder = placeholder || "";
    input.value = value || "";
    return input;
  }

  function wfIsArrayOperator(op) {
    return op === "in" || op === "not_in";
  }

  function wfBuildValueInput(field, operator, value) {
    if (field === "event_type" && wfIsArrayOperator(operator)) {
      return wfBuildCheckboxes(value);
    }
    if (wfIsArrayOperator(operator)) {
      var display = Array.isArray(value) ? value.join(", ") : (value || "");
      return wfBuildTextInput(display, "value1, value2, value3");
    }
    return wfBuildTextInput(value || "", "Value");
  }

  function wfReadValue(valueContainer) {
    // Checkboxes
    var cbs = valueContainer.querySelectorAll(".wf-event-cb");
    if (cbs.length > 0) {
      var vals = [];
      cbs.forEach(function (cb) { if (cb.checked) vals.push(cb.value); });
      return vals;
    }
    // Text input
    var input = valueContainer.querySelector(".wf-value");
    if (input) {
      var sel = valueContainer.closest(".wf-rule").querySelector(".wf-operator");
      if (sel && wfIsArrayOperator(sel.value)) {
        return input.value.split(",").map(function (s) { return s.trim(); }).filter(Boolean);
      }
      return input.value;
    }
    return "";
  }

  function wfSwapValueInput(ruleEl) {
    var fieldSel = ruleEl.querySelector(".wf-field");
    var opSel = ruleEl.querySelector(".wf-operator");
    var valueWrap = ruleEl.querySelector(".wf-value-wrap");
    var currentValue = wfReadValue(valueWrap);
    valueWrap.innerHTML = "";
    valueWrap.appendChild(wfBuildValueInput(fieldSel.value, opSel.value, currentValue));
  }

  function wfBuildRule(rule) {
    rule = rule || {};
    var field    = rule.field    || "event_type";
    var operator = rule.operator || "in";
    var value    = rule.value    || (wfIsArrayOperator(operator) ? [] : "");

    var row = document.createElement("div");
    row.className = "wf-rule";

    var fieldSel = wfBuildSelect(WF_FIELDS, field, "wf-field");
    var opSel    = wfBuildSelect(WF_OPERATORS, operator, "wf-operator");

    var valueWrap = document.createElement("div");
    valueWrap.className = "wf-value-wrap";
    valueWrap.appendChild(wfBuildValueInput(field, operator, value));

    var removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "btn btn-danger btn-sm";
    removeBtn.textContent = "\u00d7";
    removeBtn.addEventListener("click", function () { row.remove(); });

    // Swap value input when field or operator changes
    fieldSel.addEventListener("change", function () { wfSwapValueInput(row); });
    opSel.addEventListener("change", function () { wfSwapValueInput(row); });

    row.appendChild(fieldSel);
    row.appendChild(opSel);
    row.appendChild(valueWrap);
    row.appendChild(removeBtn);
    return row;
  }

  function wfBuildTarget(target) {
    target = target || {};
    var card = document.createElement("div");
    card.className = "wf-target card";

    // Header
    var header = document.createElement("div");
    header.className = "wf-target-header";
    var title = document.createElement("span");
    title.className = "wf-target-title";
    title.textContent = "Forward Target";
    var removeBtn = document.createElement("button");
    removeBtn.type = "button";
    removeBtn.className = "btn btn-danger btn-sm";
    removeBtn.textContent = "Remove";
    removeBtn.addEventListener("click", function () { card.remove(); wfUpdateNumbers(); });
    header.appendChild(title);
    header.appendChild(removeBtn);
    card.appendChild(header);

    // URL
    var urlGroup = document.createElement("div");
    urlGroup.className = "form-group";
    var urlLabel = document.createElement("label");
    urlLabel.className = "form-label";
    urlLabel.textContent = "URL";
    var urlInput = document.createElement("input");
    urlInput.type = "text";
    urlInput.className = "form-control wf-url";
    urlInput.placeholder = "https://hooks.zapier.com/hooks/catch/...";
    urlInput.value = target.url || "";
    urlGroup.appendChild(urlLabel);
    urlGroup.appendChild(urlInput);
    card.appendChild(urlGroup);

    // Rules
    var rulesLabel = document.createElement("label");
    rulesLabel.className = "form-label";
    rulesLabel.textContent = "Rules";
    rulesLabel.style.marginBottom = ".25rem";
    card.appendChild(rulesLabel);

    var rulesWrap = document.createElement("div");
    rulesWrap.className = "wf-rules";
    var rules = target.rules || [];
    rules.forEach(function (r) { rulesWrap.appendChild(wfBuildRule(r)); });
    card.appendChild(rulesWrap);

    var addRuleBtn = document.createElement("button");
    addRuleBtn.type = "button";
    addRuleBtn.className = "btn btn-outline btn-sm";
    addRuleBtn.textContent = "+ Add Rule";
    addRuleBtn.addEventListener("click", function () {
      rulesWrap.appendChild(wfBuildRule());
    });
    card.appendChild(addRuleBtn);

    return card;
  }

  function wfUpdateNumbers() {
    var targets = document.querySelectorAll(".wf-target");
    targets.forEach(function (t, i) {
      t.querySelector(".wf-target-title").textContent = "Forward Target #" + (i + 1);
    });
  }

  function wfSerialize() {
    var targets = document.querySelectorAll(".wf-target");
    var result = [];
    targets.forEach(function (t) {
      var url = t.querySelector(".wf-url").value.trim();
      if (!url) return;
      var rules = [];
      t.querySelectorAll(".wf-rule").forEach(function (r) {
        var field = r.querySelector(".wf-field").value;
        var op    = r.querySelector(".wf-operator").value;
        var val   = wfReadValue(r.querySelector(".wf-value-wrap"));
        if (wfIsArrayOperator(op) && Array.isArray(val) && val.length === 0) return;
        if (!wfIsArrayOperator(op) && val === "") return;
        rules.push({ field: field, operator: op, value: val });
      });
      var entry = { url: url };
      if (rules.length > 0) entry.rules = rules;
      result.push(entry);
    });
    return result;
  }

  function initWebhookForwardsBuilder() {
    var container = document.getElementById("wf-targets");
    var addBtn    = document.getElementById("wf-add-target");
    var hidden    = document.getElementById("webhook-forwards-json");
    if (!container || !addBtn || !hidden) return;

    // Load initial data
    var dataEl = document.getElementById("wf-initial-data");
    var initial = [];
    if (dataEl && dataEl.textContent.trim()) {
      try { initial = JSON.parse(dataEl.textContent); } catch (e) { /* ignore */ }
    }

    initial.forEach(function (t) {
      container.appendChild(wfBuildTarget(t));
    });
    wfUpdateNumbers();

    addBtn.addEventListener("click", function () {
      container.appendChild(wfBuildTarget());
      wfUpdateNumbers();
    });

    // Serialize to hidden field on submit
    var form = hidden.closest("form");
    if (form) {
      form.addEventListener("submit", function () {
        var data = wfSerialize();
        hidden.value = data.length > 0 ? JSON.stringify(data) : "";
      });
    }
  }

  // ── Boot ─────────────────────────────────────────────────────────────
  document.addEventListener("DOMContentLoaded", function () {
    initChart();
    initCopyButtons();
    initEventToggles();
    initFilterReset();
    initConfirmLinks();
    initWebhookForwardsBuilder();
  });
})();
