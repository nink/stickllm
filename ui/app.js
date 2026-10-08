(() => {
  const log = document.getElementById("log");
  const form = document.getElementById("composer");
  const input = document.getElementById("input");
  const send = document.getElementById("send");
  const statusLine = document.getElementById("statusLine");
  const modeBadge = document.getElementById("modeBadge");
  const apiHint = document.getElementById("apiHint");
  const webToggle = document.getElementById("webToggle");
  const modelsBtn = document.getElementById("modelsBtn");
  const pairBtn = document.getElementById("pairBtn");
  const modelsDialog = document.getElementById("modelsDialog");
  const modelsBody = document.getElementById("modelsBody");
  const catalogList = document.getElementById("catalogList");
  const pairDialog = document.getElementById("pairDialog");
  const pairForm = document.getElementById("pairForm");
  const pairCode = document.getElementById("pairCode");
  const pairErr = document.getElementById("pairErr");

  const API_BASE = window.STICKLLM_API || "";
  apiHint.textContent = `${location.origin}/v1`;

  const TOKEN_KEY = "stickllm_pair_token";
  let token = localStorage.getItem(TOKEN_KEY) || "";

  const messages = [
    {
      role: "system",
      content:
        "You are StickLLM, a local assistant on a Privacy AI USB. Be concise and helpful.",
    },
  ];

  function authHeaders(extra = {}) {
    const h = { ...extra };
    if (token) h.Authorization = `Bearer ${token}`;
    return h;
  }

  function addBubble(role, text) {
    const el = document.createElement("div");
    el.className = `msg ${role}`;
    const who = document.createElement("span");
    who.className = "who";
    who.textContent = role;
    el.appendChild(who);
    el.appendChild(document.createTextNode(text));
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  }

  async function pairStatus() {
    const r = await fetch("/api/pair/status", { cache: "no-store" });
    return r.json();
  }

  async function ensurePaired(force = false) {
    const st = await pairStatus();
    if (!st.require_pair) return true;
    if (st.paired && token && !force) {
      // token may still be valid
      return true;
    }
    if (!force && token) {
      // try a cheap authed call
      const t = await fetch("/api/storage", {
        headers: authHeaders(),
        cache: "no-store",
      });
      if (t.ok) return true;
    }
    pairErr.hidden = true;
    pairCode.value = "";
    pairDialog.showModal();
    pairCode.focus();
    return false;
  }

  async function refreshStatus() {
    try {
      const r = await fetch(`/health`, { cache: "no-store" });
      if (!r.ok) throw new Error(`health ${r.status}`);
      const j = await r.json();
      const paired = j.pair?.paired && token;
      statusLine.textContent = paired
        ? j.web
          ? "paired · web on"
          : "paired · LAN only"
        : j.pair?.require_pair
          ? "needs pair code (see stick screen)"
          : j.web
            ? "model ready · web on"
            : "model ready";
      try {
        const m = await fetch("/stickllm.json", { cache: "no-store" });
        if (m.ok) {
          const meta = await m.json();
          if (meta.mode) modeBadge.textContent = meta.mode;
          if (meta.version) modeBadge.title = `v${meta.version}`;
        }
      } catch (_) {}
      if (j.pair?.require_pair && !token) {
        // soft prompt once
        if (!pairDialog.open) {
          /* wait for user action */
        }
      }
    } catch (e) {
      statusLine.textContent = "waiting for model…";
    }
  }

  async function control(action, params = {}) {
    const r = await fetch("/api/control", {
      method: "POST",
      headers: authHeaders({ "Content-Type": "application/json" }),
      body: JSON.stringify({ action, params }),
    });
    if (r.status === 401) {
      token = "";
      localStorage.removeItem(TOKEN_KEY);
      await ensurePaired(true);
      throw new Error("Pair required");
    }
    const j = await r.json();
    if (!r.ok) throw new Error(j.error || j.message || `HTTP ${r.status}`);
    return j;
  }

  function renderStatus(j) {
    const s = j.storage || {};
    const p = j.probe || {};
    const active = j.active_model || "(default baked)";
    const lines = [
      s.mounted
        ? `USB DATA: mounted (${s.free_gb ?? "?"} GiB free)`
        : `USB DATA: ${s.note || "not claimed"}`,
      `VRAM: ${j.vram_gb ?? p.vram_gb ?? "?"} GB`,
      p.recommend_name
        ? `Optimum: ${p.recommend_name} (~${p.recommend_size_gb} GB)`
        : "Optimum: unknown",
      `Running: ${active}`,
      p.dest ? `Download dest: ${p.dest}` : "",
    ].filter(Boolean);
    modelsBody.textContent = lines.join("\n");
  }

  function renderCatalog(models) {
    catalogList.innerHTML = "";
    if (!models?.length) {
      catalogList.textContent = "No catalog entries.";
      return;
    }
    for (const m of models) {
      const row = document.createElement("div");
      row.className = "catalogRow";
      const meta = document.createElement("div");
      const flags = [
        m.active ? "ACTIVE" : null,
        m.installed ? "downloaded" : "not downloaded",
        m.fits_vram ? null : `needs ${m.min_vram_gb}GB VRAM`,
        m.vision ? "vision" : null,
        m.pinned ? null : "not pinned",
      ]
        .filter(Boolean)
        .join(" · ");
      meta.innerHTML = `<strong>${m.name}</strong><br/><span class="muted">${m.id} · ~${m.approx_size_gb} GB · min ${m.min_vram_gb} GB VRAM · ${flags}</span>`;

      const actions = document.createElement("div");
      actions.className = "catalogActions";

      if (m.runnable) {
        const runBtn = document.createElement("button");
        runBtn.type = "button";
        runBtn.className = "actionBtn";
        runBtn.textContent = m.active ? "Running" : "Use this";
        runBtn.disabled = !!m.active;
        runBtn.addEventListener("click", async () => {
          runBtn.disabled = true;
          runBtn.textContent = "Switching…";
          try {
            modelsBody.textContent = `Activating ${m.id}…`;
            const res = await control("model_activate", { id: m.id });
            if (!res.ok && res.error) throw new Error(res.error);
            modelsBody.textContent = `Now running: ${res.active_model || m.id}`;
            await openModels();
          } catch (e) {
            modelsBody.textContent = `Error: ${e.message}`;
            runBtn.disabled = false;
            runBtn.textContent = "Use this";
          }
        });
        actions.appendChild(runBtn);
      }

      if (m.pinned && !m.installed) {
        const dlBtn = document.createElement("button");
        dlBtn.type = "button";
        dlBtn.className = "actionBtn";
        dlBtn.textContent = "Download";
        dlBtn.addEventListener("click", async () => {
          dlBtn.disabled = true;
          dlBtn.textContent = "Downloading…";
          try {
            modelsBody.textContent = `Downloading ${m.id}… (may take a long time)`;
            const res = await control("model_download", { id: m.id });
            modelsBody.textContent =
              (res.stdout || "").slice(-1200) || JSON.stringify(res, null, 2);
            await openModels();
          } catch (e) {
            modelsBody.textContent = `Error: ${e.message}`;
            dlBtn.disabled = false;
            dlBtn.textContent = "Download";
          }
        });
        actions.appendChild(dlBtn);
      } else if (!m.pinned && !m.installed) {
        const na = document.createElement("button");
        na.type = "button";
        na.className = "actionBtn";
        na.textContent = "Unavailable";
        na.disabled = true;
        actions.appendChild(na);
      } else if (m.installed && !m.fits_vram) {
        const na = document.createElement("button");
        na.type = "button";
        na.className = "actionBtn";
        na.textContent = "Won't fit VRAM";
        na.disabled = true;
        actions.appendChild(na);
      }

      row.appendChild(meta);
      row.appendChild(actions);
      catalogList.appendChild(row);
    }
  }

  async function openModels() {
    if (!(await ensurePaired())) return;
    modelsBody.textContent = "Loading…";
    catalogList.textContent = "";
    modelsDialog.showModal();
    try {
      const st = await control("status");
      renderStatus(st);
      renderCatalog(st.catalog || []);
    } catch (e) {
      modelsBody.textContent = `Could not load: ${e.message}`;
    }
  }

  async function chat(userText) {
    if (!(await ensurePaired())) return;
    messages.push({ role: "user", content: userText });
    addBubble("user", userText);
    const assistantEl = addBubble("assistant", "…");
    send.disabled = true;
    const web = webToggle?.checked ? "on" : "off";

    try {
      const r = await fetch(`${API_BASE}/v1/chat/completions`, {
        method: "POST",
        headers: authHeaders({ "Content-Type": "application/json" }),
        body: JSON.stringify({
          model: "stickllm",
          messages,
          stream: false,
          temperature: 0.7,
          web,
        }),
      });
      if (r.status === 401) {
        token = "";
        localStorage.removeItem(TOKEN_KEY);
        assistantEl.lastChild.textContent = "Pair required — enter the code from the stick screen.";
        await ensurePaired(true);
        return;
      }
      if (!r.ok) {
        const t = await r.text();
        throw new Error(t || `HTTP ${r.status}`);
      }
      const data = await r.json();
      let reply =
        data?.choices?.[0]?.message?.content?.trim() || "(empty response)";
      const webInfo = data?.stickllm_web;
      if (webInfo?.used && webInfo.results?.length) {
        const cites = webInfo.results
          .slice(0, 3)
          .map((x) => x.url)
          .filter(Boolean);
        if (cites.length) {
          reply += "\n\nSources:\n" + cites.map((u) => `• ${u}`).join("\n");
        }
      }
      messages.push({ role: "assistant", content: reply });
      assistantEl.lastChild.textContent = reply;
    } catch (err) {
      assistantEl.classList.add("system");
      assistantEl.lastChild.textContent = `Error: ${err.message}`;
    } finally {
      send.disabled = false;
      input.focus();
    }
  }

  form.addEventListener("submit", (ev) => {
    ev.preventDefault();
    const text = input.value.trim();
    if (!text || send.disabled) return;
    input.value = "";
    chat(text);
  });

  input.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter" && !ev.shiftKey) {
      ev.preventDefault();
      form.requestSubmit();
    }
  });

  pairForm?.addEventListener("submit", async (ev) => {
    ev.preventDefault();
    pairErr.hidden = true;
    const code = pairCode.value.trim();
    try {
      const r = await fetch("/api/pair", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ code }),
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.message || j.error || "Pair failed");
      token = j.token;
      localStorage.setItem(TOKEN_KEY, token);
      pairDialog.close();
      statusLine.textContent = "paired";
      addBubble("system", "Paired with StickLLM. Chat and Models menu are unlocked until reboot.");
    } catch (e) {
      pairErr.textContent = e.message;
      pairErr.hidden = false;
    }
  });

  modelsBtn?.addEventListener("click", () => openModels());
  pairBtn?.addEventListener("click", () => ensurePaired(true));
  document.getElementById("modelsClose")?.addEventListener("click", () =>
    modelsDialog.close()
  );

  document.getElementById("actClaim")?.addEventListener("click", async () => {
    modelsBody.textContent = "Claiming USB free space…";
    try {
      const res = await control("usb_claim");
      modelsBody.textContent = (res.stdout || JSON.stringify(res, null, 2)).slice(-1500);
      await openModels();
    } catch (e) {
      modelsBody.textContent = `Error: ${e.message}`;
    }
  });
  document.getElementById("actProbe")?.addEventListener("click", async () => {
    modelsBody.textContent = "Probing…";
    try {
      await control("model_probe");
      await openModels();
    } catch (e) {
      modelsBody.textContent = `Error: ${e.message}`;
    }
  });
  document.getElementById("actDownload")?.addEventListener("click", async () => {
    modelsBody.textContent = "Downloading recommended model…";
    try {
      const st = await control("status");
      const id = st.probe?.recommend_id;
      const res = await control("model_download", id ? { id } : {});
      modelsBody.textContent = (res.stdout || JSON.stringify(res, null, 2)).slice(-1500);
      await openModels();
    } catch (e) {
      modelsBody.textContent = `Error: ${e.message}`;
    }
  });
  document.getElementById("actRefresh")?.addEventListener("click", () => openModels());

  addBubble(
    "system",
    "StickLLM v0.2 — pair with the code on the computer screen, then use Models for USB/downloads (no SSH)."
  );
  refreshStatus();
  setInterval(refreshStatus, 8000);
  ensurePaired(false);
})();
