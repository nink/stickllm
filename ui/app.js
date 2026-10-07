(() => {
  const log = document.getElementById("log");
  const form = document.getElementById("composer");
  const input = document.getElementById("input");
  const send = document.getElementById("send");
  const statusLine = document.getElementById("statusLine");
  const modeBadge = document.getElementById("modeBadge");
  const apiHint = document.getElementById("apiHint");

  // Same host: UI on :80, llama.cpp on :8080 (or relative proxy if present)
  const API_BASE = window.STICKLLM_API || `${location.protocol}//${location.hostname}:8080`;
  apiHint.textContent = `${API_BASE}/v1`;

  const messages = [
    {
      role: "system",
      content:
        "You are StickLLM, a local assistant. You run entirely on the user's machine. Be concise and helpful.",
    },
  ];

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

  async function refreshStatus() {
    try {
      const r = await fetch(`${API_BASE}/health`, { cache: "no-store" });
      if (!r.ok) throw new Error(`health ${r.status}`);
      statusLine.textContent = "model ready · LAN only";
      try {
        const m = await fetch("/stickllm.json", { cache: "no-store" });
        if (m.ok) {
          const j = await m.json();
          if (j.mode) modeBadge.textContent = j.mode;
        }
      } catch (_) {
        /* optional */
      }
    } catch (e) {
      statusLine.textContent = "waiting for llama-server…";
    }
  }

  async function chat(userText) {
    messages.push({ role: "user", content: userText });
    addBubble("user", userText);
    const assistantEl = addBubble("assistant", "…");
    send.disabled = true;

    try {
      const r = await fetch(`${API_BASE}/v1/chat/completions`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: "stickllm",
          messages: messages.filter((m) => m.role !== "system").length
            ? messages
            : messages,
          stream: false,
          temperature: 0.7,
        }),
      });
      if (!r.ok) {
        const t = await r.text();
        throw new Error(t || `HTTP ${r.status}`);
      }
      const data = await r.json();
      const reply =
        data?.choices?.[0]?.message?.content?.trim() || "(empty response)";
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

  addBubble(
    "system",
    "Ephemeral session. Chats die on reboot. Persist config / Download model are explicit actions on the stick."
  );
  refreshStatus();
  setInterval(refreshStatus, 8000);
})();
