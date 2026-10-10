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
  const revokeBtn = document.getElementById("revokeBtn");
  const modelsDialog = document.getElementById("modelsDialog");
  const modelsBody = document.getElementById("modelsBody");
  const catalogList = document.getElementById("catalogList");
  const pairDialog = document.getElementById("pairDialog");
  const pairForm = document.getElementById("pairForm");
  const pairCode = document.getElementById("pairCode");
  const pairErr = document.getElementById("pairErr");
  let localTrust = false;

  const API_BASE = window.STICKLLM_API || "";
  apiHint.textContent = `${location.origin}/v1`;

  const TOKEN_KEY = "stickllm_pair_token";
  let token = localStorage.getItem(TOKEN_KEY) || "";
  let dlPollTimer = null;

  let dlProgress = document.getElementById("dlProgress");
  let dlProgressLabel = document.getElementById("dlProgressLabel");
  let dlProgressFill = document.getElementById("dlProgressFill");
  let dlProgressBar = document.getElementById("dlProgressBar");
  let dlProgressMeta = document.getElementById("dlProgressMeta");
  let lastDownload = {};
  let modelLoading = false;
  let loadPollTimer = null;

  function ensureDlProgressDom() {
    if (dlProgress && dlProgressFill) return;
    const panel = modelsDialog?.querySelector(".modelsPanel");
    if (!panel || !modelsBody) return;
    const box = document.createElement("div");
    box.id = "dlProgress";
    box.className = "dlProgress";
    box.hidden = true;
    box.innerHTML =
      '<div class="dlProgressLabel" id="dlProgressLabel">Downloading…</div>' +
      '<div class="dlProgressTrack" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="0" id="dlProgressBar">' +
      '<div class="dlProgressFill" id="dlProgressFill"></div></div>' +
      '<div class="dlProgressMeta" id="dlProgressMeta"></div>';
    modelsBody.insertAdjacentElement("afterend", box);
    dlProgress = box;
    dlProgressLabel = document.getElementById("dlProgressLabel");
    dlProgressFill = document.getElementById("dlProgressFill");
    dlProgressBar = document.getElementById("dlProgressBar");
    dlProgressMeta = document.getElementById("dlProgressMeta");
  }

  function fmtBytes(n) {
    if (!n || n < 0) return "—";
    const gb = n / (1024 ** 3);
    if (gb >= 1) return `${gb.toFixed(2)} GB`;
    const mb = n / (1024 ** 2);
    return `${mb.toFixed(0)} MB`;
  }

  function renderDownload(d) {
    ensureDlProgressDom();
    lastDownload = d || {};
    if (!dlProgress) return false;
    const state = d?.state || "idle";
    if (state === "idle" || !state) {
      dlProgress.hidden = true;
      return false;
    }
    if (state === "done") {
      dlProgress.hidden = false;
      dlProgressLabel.textContent = `Downloaded: ${d.name || d.id || "model"}`;
      dlProgressFill.style.width = "100%";
      dlProgressBar.setAttribute("aria-valuenow", "100");
      dlProgressMeta.textContent = "Complete — hash verified";
      return true;
    }
    if (!["downloading", "verifying", "starting", "failed"].includes(state)) {
      dlProgress.hidden = true;
      return false;
    }
    dlProgress.hidden = false;
    const pct = d.percent == null ? null : Number(d.percent);
    const label =
      state === "verifying"
        ? `Verifying ${d.name || d.id || "model"}…`
        : state === "failed"
          ? `Download failed: ${d.name || d.id || "model"}`
          : `Downloading ${d.name || d.id || "model"}…`;
    dlProgressLabel.textContent = label;
    if (pct == null) {
      dlProgressFill.style.width = "15%";
      dlProgressFill.style.opacity = "0.6";
      dlProgressBar.setAttribute("aria-valuenow", "0");
      dlProgressMeta.textContent = d.note || "in progress…";
    } else {
      dlProgressFill.style.opacity = "1";
      dlProgressFill.style.width = `${Math.max(1, Math.min(100, pct))}%`;
      dlProgressBar.setAttribute("aria-valuenow", String(Math.round(pct)));
      dlProgressMeta.textContent = `${pct.toFixed(1)}% · ${fmtBytes(d.bytes_done)} / ${fmtBytes(d.bytes_total)}${d.file ? " · " + d.file : ""}`;
    }
    // Also mirror into status text so it's obvious even if bar CSS missing
    if (modelsBody && state === "downloading" && pct != null) {
      const base = modelsBody.textContent || "";
      if (!base.includes("Download:")) {
        /* keep storage lines; append handled in openModels */
      }
    }
    return true;
  }

  function stopDlPoll() {
    if (dlPollTimer) {
      clearInterval(dlPollTimer);
      dlPollTimer = null;
    }
  }

  function startDlPoll() {
    stopDlPoll();
    dlPollTimer = setInterval(async () => {
      if (!modelsDialog.open) {
        stopDlPoll();
        return;
      }
      try {
        const st = await control("status");
        const d = st.download || {};
        renderDownload(d);
        if (["downloading", "verifying", "starting"].includes(d.state)) {
          renderStatus(st);
          if (d.percent != null) {
            modelsBody.textContent =
              (modelsBody.dataset.baseStatus || modelsBody.textContent.split("\nDownload:")[0]) +
              `\nDownload: ${d.name || d.id} — ${Number(d.percent).toFixed(1)}%` +
              ` (${fmtBytes(d.bytes_done)} / ${fmtBytes(d.bytes_total)})`;
          }
          renderCatalog(st.catalog || []);
        } else if (d.state === "done") {
          renderStatus(st);
          renderCatalog(st.catalog || []);
        }
      } catch (_) {}
    }, 1500);
  }

  const messages = [
    {
      role: "system",
      content:
        "You are StickLLM, a local assistant on a Privacy AI USB. Be concise and helpful. Always use earlier turns in this conversation when answering follow-ups. If the user attaches images, describe and reason about them.",
    },
  ];

  /** @type {{ dataUrl: string, mime: string }[]} */
  let pendingImages = [];
  const imageInput = document.getElementById("imageInput");
  const attachBar = document.getElementById("attachBar");

  function renderAttachments() {
    if (!attachBar) return;
    attachBar.innerHTML = "";
    if (!pendingImages.length) {
      attachBar.hidden = true;
      return;
    }
    attachBar.hidden = false;
    pendingImages.forEach((img, idx) => {
      const wrap = document.createElement("div");
      wrap.className = "attachThumb";
      const el = document.createElement("img");
      el.src = img.dataUrl;
      el.alt = `attachment ${idx + 1}`;
      const rm = document.createElement("button");
      rm.type = "button";
      rm.textContent = "×";
      rm.title = "Remove";
      rm.addEventListener("click", () => {
        pendingImages.splice(idx, 1);
        renderAttachments();
      });
      wrap.appendChild(el);
      wrap.appendChild(rm);
      attachBar.appendChild(wrap);
    });
  }

  function addPendingDataUrl(dataUrl, mime) {
    if (!dataUrl || !String(dataUrl).startsWith("data:image/")) return;
    if (pendingImages.length >= 4) {
      addBubble("system", "Max 4 images per message.");
      return;
    }
    pendingImages.push({ dataUrl, mime: mime || "image/png" });
    renderAttachments();
  }

  function readFileAsDataUrl(file) {
    return new Promise((resolve, reject) => {
      const fr = new FileReader();
      fr.onload = () => resolve(String(fr.result || ""));
      fr.onerror = () => reject(fr.error || new Error("read failed"));
      fr.readAsDataURL(file);
    });
  }

  async function ingestImageFiles(fileList) {
    const files = Array.from(fileList || []).filter((f) => f.type.startsWith("image/"));
    for (const f of files) {
      if (f.size > 8 * 1024 * 1024) {
        addBubble("system", `Skipped ${f.name} (over 8 MB).`);
        continue;
      }
      try {
        const dataUrl = await readFileAsDataUrl(f);
        addPendingDataUrl(dataUrl, f.type);
      } catch (e) {
        addBubble("system", `Could not read ${f.name}: ${e.message || e}`);
      }
    }
  }

  function authHeaders(extra = {}) {
    const h = { ...extra };
    if (token) h.Authorization = `Bearer ${token}`;
    return h;
  }

  function addBubble(role, text, imageUrls) {
    const el = document.createElement("div");
    el.className = `msg ${role}`;
    const who = document.createElement("span");
    who.className = "who";
    who.textContent = role;
    el.appendChild(who);
    if (imageUrls?.length) {
      const row = document.createElement("div");
      row.className = "attachBar";
      row.style.margin = "0.35rem 0";
      for (const u of imageUrls) {
        const thumb = document.createElement("div");
        thumb.className = "attachThumb";
        const img = document.createElement("img");
        img.src = u;
        img.alt = "attached";
        thumb.appendChild(img);
        row.appendChild(thumb);
      }
      el.appendChild(row);
    }
    el.appendChild(document.createTextNode(text));
    log.appendChild(el);
    log.scrollTop = log.scrollHeight;
    return el;
  }

  async function pairStatus() {
    const r = await fetch("/api/pair/status", { cache: "no-store" });
    return r.json();
  }

  function syncPairButtons(st) {
    if (st && typeof st.local_trust === "boolean") localTrust = st.local_trust;
    if (pairBtn) pairBtn.hidden = !!localTrust;
    // LAN: show when this browser holds a token. Local stick: can mint a new LAN code.
    if (revokeBtn) revokeBtn.hidden = !(token || localTrust);
  }

  async function ensurePaired(force = false) {
    const st = await pairStatus();
    syncPairButtons(st);
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

  async function revokePair() {
    try {
      const r = await fetch("/api/pair/revoke", {
        method: "POST",
        headers: authHeaders({ "Content-Type": "application/json" }),
        body: "{}",
        credentials: "same-origin",
      });
      const j = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(j.message || j.error || "Revoke failed");
      token = "";
      localStorage.removeItem(TOKEN_KEY);
      syncPairButtons({ local_trust: localTrust });
      statusLine.textContent = "pair revoked — enter new code from stick screen";
      addBubble(
        "system",
        j.hint ||
          "Pair revoked. New code is on the StickLLM screen — enter it here or in another browser."
      );
      if (!localTrust) await ensurePaired(true);
      else await refreshStatus();
    } catch (e) {
      addBubble("system", `Disconnect failed: ${e.message}`);
    }
  }

  function setComposerLoading(loading) {
    modelLoading = !!loading;
    if (send) send.disabled = !!loading;
    if (input) {
      input.disabled = !!loading;
      input.placeholder = loading
        ? "Model loading into VRAM — wait…"
        : "Ask anything (pair first if prompted)";
    }
  }

  function stopLoadPoll() {
    if (loadPollTimer) {
      clearInterval(loadPollTimer);
      loadPollTimer = null;
    }
  }

  async function waitForModelReady(label) {
    setComposerLoading(true);
    statusLine.textContent = `loading ${label || "model"} into VRAM…`;
    if (modelsBody) {
      modelsBody.textContent =
        `Loading ${label || "model"} into GPU VRAM…\n` +
        "Chat is paused until READY (large models can take several minutes).";
    }
    stopLoadPoll();
    const started = Date.now();
    return new Promise((resolve) => {
      loadPollTimer = setInterval(async () => {
        const elapsed = Math.round((Date.now() - started) / 1000);
        try {
          const st = await control("status");
          const llm = st.llm || {};
          const name =
            (llm.target || "").split("\n")[1] ||
            (llm.target || "").split("\n")[0] ||
            label ||
            "model";
          if (llm.ready && !llm.loading) {
            stopLoadPoll();
            setComposerLoading(false);
            statusLine.textContent = "paired · model ready";
            if (modelsBody) {
              modelsBody.textContent = `READY — ${name} loaded (${elapsed}s)`;
            }
            resolve(true);
            return;
          }
          statusLine.textContent = `loading ${name}… ${elapsed}s`;
          if (modelsBody) {
            modelsBody.textContent =
              `Loading ${name} into GPU VRAM… ${elapsed}s\n` +
              "Chat paused until health is green. Do not reboot.";
          }
        } catch (_) {
          statusLine.textContent = `loading model… ${elapsed}s`;
        }
        if (elapsed > 900) {
          stopLoadPoll();
          setComposerLoading(false);
          statusLine.textContent = "model load timed out — check stick";
          resolve(false);
        }
      }, 2000);
    });
  }

  async function refreshStatus() {
    try {
      // Prefer control status (includes llm.loading) when paired.
      if (token) {
        try {
          const st = await control("status");
          const llm = st.llm || {};
          if (llm.loading || !llm.ready) {
            setComposerLoading(true);
            const name =
              (llm.target || "").split("\n")[1] ||
              (llm.target || "").split("\n")[0] ||
              "model";
            statusLine.textContent = `loading ${name} into VRAM…`;
            return;
          }
          if (modelLoading) setComposerLoading(false);
        } catch (_) {
          /* fall through to /health */
        }
      }
      const r = await fetch(`/health`, { cache: "no-store" });
      if (!r.ok) throw new Error(`health ${r.status}`);
      const j = await r.json();
      const requirePair = !!j.pair?.require_pair;
      const serverPaired = !!j.pair?.paired;
      const clientPaired = !!(token && serverPaired);
      syncPairButtons(j.pair || {});
      if (!requirePair) {
        statusLine.textContent = j.web ? "model ready · web on" : "model ready";
      } else if (clientPaired) {
        statusLine.textContent = j.web ? "paired · web on" : "paired · LAN only";
      } else if (token && !serverPaired) {
        statusLine.textContent = "pair expired — tap Pair for a new code";
      } else {
        statusLine.textContent = "needs pair code (see stick screen)";
      }
      try {
        const m = await fetch("/stickllm.json", { cache: "no-store" });
        if (m.ok) {
          const meta = await m.json();
          if (meta.mode) modeBadge.textContent = meta.mode;
          if (meta.version) modeBadge.title = `v${meta.version}`;
        }
      } catch (_) {}
    } catch (e) {
      setComposerLoading(true);
      statusLine.textContent = token
        ? "paired · loading model into VRAM…"
        : "waiting for model…";
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
        ? `USB DATA: mounted (${s.free_gb ?? "?"} GiB free) — auto-claimed on boot`
        : `USB DATA: ${s.note || "not claimed"}`,
      `VRAM: ${j.vram_gb ?? p.vram_gb ?? "?"} GB`,
      p.recommend_name
        ? `Optimum: ${p.recommend_name} (~${p.recommend_size_gb} GB)`
        : "Optimum: unknown",
      `Running: ${active}`,
      p.dest ? `Download dest: ${p.dest}` : "",
    ].filter(Boolean);
    const text = lines.join("\n");
    modelsBody.textContent = text;
    modelsBody.dataset.baseStatus = text;
    // Claim is boot auto; only show the button when DATA is not mounted yet.
    const claimBtn = document.getElementById("actClaim");
    if (claimBtn) {
      claimBtn.hidden = !!s.mounted;
      claimBtn.textContent = "Claim USB free space";
    }
  }

  function renderCatalog(models) {
    catalogList.innerHTML = "";
    if (!models?.length) {
      catalogList.textContent = "No catalog entries.";
      return;
    }
    const dl = lastDownload || {};
    const dlBusy = ["downloading", "verifying", "starting"].includes(dl.state);
    for (const m of models) {
      const row = document.createElement("div");
      row.className = "catalogRow";
      const meta = document.createElement("div");
      const isThisDl = dlBusy && dl.id === m.id;
      const flags = [
        m.active ? "ACTIVE" : null,
        isThisDl
          ? `DOWNLOADING ${dl.percent != null ? dl.percent.toFixed(0) + "%" : "…"}`
          : m.installed
            ? "downloaded"
            : "not downloaded",
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
          runBtn.textContent = "Loading…";
          try {
            modelsBody.textContent =
              `Starting ${m.name || m.id}…\nRestarting llama-server — loading into VRAM.`;
            statusLine.textContent = `loading ${m.name || m.id}…`;
            setComposerLoading(true);
            const res = await control("model_activate", { id: m.id });
            if (!res.ok && res.error) throw new Error(res.error);
            await waitForModelReady(res.name || m.name || m.id);
            await openModels();
          } catch (e) {
            setComposerLoading(false);
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
        if (isThisDl) {
          dlBtn.textContent =
            dl.percent != null ? `${Number(dl.percent).toFixed(0)}%…` : "Downloading…";
          dlBtn.disabled = true;
        } else if (dlBusy) {
          dlBtn.textContent = "Wait…";
          dlBtn.disabled = true;
        } else {
          dlBtn.textContent = "Download";
        }
        dlBtn.addEventListener("click", async () => {
          dlBtn.disabled = true;
          dlBtn.textContent = "Starting…";
          try {
            const res = await control("model_download", { id: m.id });
            const d = res.download || { state: "starting", name: m.name, id: m.id };
            renderDownload(d);
            if (res.already_running) {
              modelsBody.textContent =
                `Already downloading ${d.name || m.id}` +
                (d.percent != null ? ` — ${Number(d.percent).toFixed(1)}%` : "") +
                " (leave this panel open to watch)";
            } else {
              modelsBody.textContent = `Downloading ${m.name || m.id}…`;
            }
            startDlPoll();
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
    ensureDlProgressDom();
    startDlPoll();
    try {
      const st = await control("status");
      renderStatus(st);
      const d = st.download || {};
      renderDownload(d);
      if (["downloading", "verifying", "starting"].includes(d.state)) {
        const pct = d.percent != null ? `${Number(d.percent).toFixed(1)}%` : "…";
        modelsBody.textContent =
          (modelsBody.textContent ? modelsBody.textContent + "\n" : "") +
          `Download: ${d.name || d.id || "model"} — ${pct}` +
          (d.bytes_done
            ? ` (${fmtBytes(d.bytes_done)} / ${fmtBytes(d.bytes_total)})`
            : "");
      }
      renderCatalog(st.catalog || []);
    } catch (e) {
      modelsBody.textContent = `Could not load: ${e.message}`;
    }
  }

  function buildUserContent(userText, images) {
    if (!images?.length) return userText;
    const parts = [];
    const text = (userText || "").trim() || "What do you see in this image?";
    parts.push({ type: "text", text });
    for (const img of images) {
      parts.push({
        type: "image_url",
        image_url: { url: img.dataUrl },
      });
    }
    return parts;
  }

  async function chat(userText, images) {
    if (!(await ensurePaired())) return;
    if (modelLoading) {
      addBubble("system", "Model is still loading into VRAM — wait for status to say ready.");
      return;
    }
    // Fast preflight so we don't send a chat into a restarting llama.
    try {
      const h = await fetch("/health", { cache: "no-store" });
      if (!h.ok) {
        setComposerLoading(true);
        statusLine.textContent = "loading model into VRAM…";
        addBubble("system", "Model not ready yet (loading into GPU). Try again when status is ready.");
        return;
      }
    } catch (_) {
      setComposerLoading(true);
      addBubble("system", "Model not ready yet (loading into GPU). Try again shortly.");
      return;
    }
    const imgs = images || [];
    const content = buildUserContent(userText, imgs);
    messages.push({ role: "user", content });
    const preview =
      typeof content === "string"
        ? content
        : content.find((p) => p.type === "text")?.text || "(image)";
    addBubble(
      "user",
      preview,
      imgs.map((i) => i.dataUrl)
    );
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
      if (r.status === 503 || r.status === 502) {
        setComposerLoading(true);
        assistantEl.classList.add("system");
        assistantEl.lastChild.textContent =
          "Model is loading into VRAM — chat paused. Wait for status “ready”, then retry.";
        // drop the optimistic user turn from history so retry is clean
        if (messages.length && messages[messages.length - 1].role === "user") {
          messages.pop();
        }
        return;
      }
      if (!r.ok) {
        const t = await r.text();
        throw new Error(t || `HTTP ${r.status}`);
      }
      const data = await r.json();
      const reply =
        data?.choices?.[0]?.message?.content?.trim() || "(empty response)";
      // Keep history lean — sources are display-only (don't bloat context).
      messages.push({ role: "assistant", content: reply });
      let shown = reply;
      const webInfo = data?.stickllm_web;
      if (webInfo?.used && webInfo.results?.length) {
        const cites = webInfo.results
          .slice(0, 3)
          .map((x) => x.url)
          .filter(Boolean);
        if (cites.length) {
          shown += "\n\nSources:\n" + cites.map((u) => `• ${u}`).join("\n");
        }
      }
      assistantEl.lastChild.textContent = shown;
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
    const imgs = pendingImages.slice();
    if ((!text && !imgs.length) || send.disabled) return;
    input.value = "";
    pendingImages = [];
    renderAttachments();
    chat(text, imgs);
  });

  input.addEventListener("keydown", (ev) => {
    if (ev.key === "Enter" && !ev.shiftKey) {
      ev.preventDefault();
      form.requestSubmit();
    }
  });

  input.addEventListener("paste", (ev) => {
    const items = ev.clipboardData?.items;
    if (!items) return;
    const files = [];
    for (const it of items) {
      if (it.type.startsWith("image/")) {
        const f = it.getAsFile();
        if (f) files.push(f);
      }
    }
    if (files.length) {
      ev.preventDefault();
      ingestImageFiles(files);
    }
  });

  imageInput?.addEventListener("change", async () => {
    if (imageInput.files?.length) {
      await ingestImageFiles(imageInput.files);
      imageInput.value = "";
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
        credentials: "same-origin",
      });
      const j = await r.json();
      if (!r.ok) throw new Error(j.message || j.error || "Pair failed");
      token = j.token;
      localStorage.setItem(TOKEN_KEY, token);
      syncPairButtons({ local_trust: localTrust });
      pairDialog.close();
      statusLine.textContent = j.tls ? "paired · TLS · web on" : "paired · web on";
      addBubble(
        "system",
        "Paired with StickLLM. Chat and Models are unlocked until Disconnect or reboot."
      );
      if (j.chat_frontend === "openwebui" && !location.pathname.startsWith("/stickllm")) {
        location.reload();
        return;
      }
      await refreshStatus();
    } catch (e) {
      pairErr.textContent = e.message;
      pairErr.hidden = false;
    }
  });

  modelsBtn?.addEventListener("click", () => openModels());
  pairBtn?.addEventListener("click", () => ensurePaired(true));
  revokeBtn?.addEventListener("click", () => revokePair());
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
    modelsBody.textContent = "Starting recommended download…";
    try {
      const st = await control("status");
      const id = st.probe?.recommend_id;
      const res = await control("model_download", id ? { id } : {});
      modelsBody.textContent = res.already_running
        ? "Download already in progress — see bar above."
        : "Download started — see progress bar.";
      renderDownload(res.download || { state: "starting" });
      startDlPoll();
    } catch (e) {
      modelsBody.textContent = `Error: ${e.message}`;
    }
  });
  document.getElementById("actRefresh")?.addEventListener("click", () => openModels());
  modelsDialog?.addEventListener("close", () => stopDlPoll());

  addBubble(
    "system",
    "StickLLM v0.3 — native UI. LAN: pair with the code on the stick screen. Same-box Local: no pair. Models: USB/downloads."
  );
  refreshStatus();
  setInterval(refreshStatus, 8000);
  pairStatus()
    .then((st) => syncPairButtons(st))
    .catch(() => {});
  ensurePaired(false);
})();
