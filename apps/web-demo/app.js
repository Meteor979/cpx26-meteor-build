(function () {
  "use strict";

  const data = window.WEARWISE_DEMO_DATA;
  const engine = window.WearWiseEngine;
  if (!data || !engine) {
    throw new Error("WearWise demo modules did not load.");
  }

  const STORAGE = {
    garments: "wearwise-web-garments-v1",
    recent: "wearwise-web-recent-plan-v1",
    contrast: "wearwise-web-high-contrast"
  };

  const state = {
    garments: loadGarments(),
    occasion: null,
    outfits: [],
    pendingPhoto: null,
    activeOutfit: null
  };

  const screens = [...document.querySelectorAll("[data-screen]")];
  const wardrobeGrid = document.querySelector("#wardrobe-grid");
  const outfitList = document.querySelector("#outfit-list");
  const occasionInput = document.querySelector("#occasion-input");
  const formalitySelect = document.querySelector("#occasion-formality");
  const occasionResult = document.querySelector("#occasion-result");
  const resultsTitle = document.querySelector("#results-title");
  const resultsNote = document.querySelector("#results-note");
  const detailDialog = document.querySelector("#detail-dialog");
  const detailContent = document.querySelector("#detail-content");
  const toast = document.querySelector("#toast");
  const reduceMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)"
  );
  let navigationTimer = null;

  function loadGarments() {
    try {
      const saved = JSON.parse(localStorage.getItem(STORAGE.garments));
      if (Array.isArray(saved) && saved.length) return saved;
    } catch {
      // Invalid local data falls back to the bundled demo wardrobe.
    }
    return structuredClone(data.garments);
  }

  function persistGarments() {
    try {
      localStorage.setItem(STORAGE.garments, JSON.stringify(state.garments));
    } catch {
      showToast("照片过大，本次展示已生效，但无法写入浏览器本地存储。");
    }
  }

  function escapeHTML(value) {
    return String(value ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
  }

  let toastTimer;
  function showToast(message) {
    toast.textContent = message;
    toast.classList.add("show");
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.remove("show"), 2600);
  }

  function go(route) {
    if (navigationTimer) return;
    const next = screens.find(
      (screen) => screen.dataset.screen === route
    );
    if (!next) return;

    if (route === "wardrobe") renderWardrobe();
    if (route === "home") renderHome();
    const current = screens.find((screen) => !screen.hidden);

    const heading = document.querySelector(
      `[data-screen="${route}"] h1`
    );
    heading?.setAttribute?.("tabindex", "-1");

    const showNext = () => {
      next.hidden = false;
      next.classList.remove("is-leaving");
      next.classList.add("is-entering");
      requestAnimationFrame(() => {
        requestAnimationFrame(() => {
          next.classList.remove("is-entering");
          navigationTimer = null;
          heading?.focus?.();
          window.scrollTo({
            top: 0,
            behavior: reduceMotion.matches ? "auto" : "smooth"
          });
        });
      });
    };

    if (!current || current === next) {
      showNext();
      return;
    }

    current.classList.remove("is-entering");
    current.classList.add("is-leaving");
    navigationTimer = setTimeout(
      () => {
        current.hidden = true;
        current.classList.remove("is-leaving");
        showNext();
      },
      reduceMotion.matches ? 0 : 165
    );
  }

  function closeDetail() {
    if (!detailDialog.open) return;
    detailDialog.classList.remove("is-visible");
    setTimeout(
      () => {
        if (detailDialog.open) detailDialog.close();
      },
      reduceMotion.matches ? 0 : 150
    );
  }

  function renderHome() {
    const count = state.garments.length;
    document.querySelector("#wardrobe-summary").textContent =
      count ? `${count} 件衣物` : "添加第一件衣物";
    renderRecentPlan();
  }

  function photoMarkup(garment) {
    if (!garment?.photo) {
      return `<div class="missing-photo">${escapeHTML(
        garment?.name || "衣物"
      )}，照片缺失</div>`;
    }
    return `<img src="${garment.photo}" alt="${escapeHTML(
      garment.name
    )}的照片" />`;
  }

  function garmentCard(garment) {
    return `
      <article class="garment-card">
        <div class="photo-frame">${photoMarkup(garment)}</div>
        <div class="garment-name">${escapeHTML(garment.name)}</div>
        <div class="garment-meta">${engine.SLOT_LABEL[garment.slot]} · ${escapeHTML(
          garment.colors.join("、")
        )} · 正式度 ${garment.formality}</div>
      </article>
    `;
  }

  function renderWardrobe() {
    wardrobeGrid.innerHTML = state.garments.map(garmentCard).join("");
  }

  function renderOutfits() {
    outfitList.innerHTML = state.outfits
      .map((outfit) => {
        const photos = outfit.items
          .map(
            (item) => `
              <div>
                <div class="photo-frame">${photoMarkup(item)}</div>
                <div class="garment-name">${escapeHTML(item.name)}</div>
              </div>
            `
          )
          .join("");
        return `
          <article class="outfit-card">
            <div class="outfit-header">
              <div>
                <p class="eyebrow">方案</p>
                <h2>${escapeHTML(outfit.title)}</h2>
              </div>
              <span class="source-badge">${escapeHTML(outfit.source)}</span>
            </div>
            <div class="outfit-photos">${photos}</div>
            <p class="outfit-reason">${escapeHTML(outfit.reasons[0])}</p>
            <button class="outline-button detail-button" type="button" data-outfit-id="${outfit.id}">
              查看详情
            </button>
          </article>
        `;
      })
      .join("");

    outfitList.querySelectorAll(".detail-button").forEach((button) => {
      button.addEventListener("click", () => {
        const outfit = state.outfits.find(
          (candidate) => candidate.id === button.dataset.outfitId
        );
        if (outfit) openDetail(outfit);
      });
    });
  }

  function openDetail(outfit) {
    state.activeOutfit = outfit;
    const photos = outfit.items
      .map(
        (item) => `
          <article class="garment-card">
            <div class="photo-frame">${photoMarkup(item)}</div>
            <div class="garment-name">${escapeHTML(item.name)}</div>
            <div class="garment-meta">${engine.SLOT_LABEL[item.slot]}</div>
          </article>
        `
      )
      .join("");
    const currentIDs = new Set(outfit.items.map((item) => item.id));
    const options = [];
    outfit.items.forEach((item) => {
      state.garments
        .filter(
          (candidate) =>
            candidate.slot === item.slot && !currentIDs.has(candidate.id)
        )
        .forEach((candidate) => {
          options.push(
            `<option value="${candidate.id}">${escapeHTML(
              item.name
            )} → ${escapeHTML(candidate.name)}</option>`
          );
        });
    });

    detailContent.innerHTML = `
      <p class="eyebrow">搭配详情</p>
      <h2>${escapeHTML(outfit.title)}</h2>
      <p class="lead">${escapeHTML(engine.FORMALITY_LABEL[state.occasion.formality])} · ${escapeHTML(
        state.occasion.name
      )}</p>
      <div class="outfit-photos">${photos}</div>
      <ul class="detail-list">
        ${outfit.reasons.map((reason) => `<li>${escapeHTML(reason)}</li>`).join("")}
      </ul>
      <p><strong>取舍：</strong>${escapeHTML(outfit.tradeoffs.join(" "))}</p>
      <p><strong>来源：</strong>${escapeHTML(outfit.source)}</p>
      ${
        options.length
          ? `<div class="replace-row">
              <label>替换同槽位单品
                <select id="replacement-select">${options.join("")}</select>
              </label>
              <button id="replace-button" class="outline-button" type="button">替换单品</button>
            </div>`
          : "<p>没有可替换的同槽位衣物。</p>"
      }
      <button id="save-outfit-button" class="primary-button" type="button">确认这套</button>
      <button id="return-results-button" class="outline-button" type="button">返回三套搭配</button>
    `;

    detailContent
      .querySelector("#replace-button")
      ?.addEventListener("click", () => {
        const id = detailContent.querySelector("#replacement-select").value;
        const replacement = state.garments.find((item) => item.id === id);
        const index = state.outfits.findIndex(
          (item) => item.id === state.activeOutfit.id
        );
        state.activeOutfit = engine.replaceItem(
          state.activeOutfit,
          replacement,
          state.garments
        );
        if (index >= 0) state.outfits[index] = state.activeOutfit;
        renderOutfits();
        openDetail(state.activeOutfit);
        showToast("已替换同槽位单品");
      });
    detailContent
      .querySelector("#save-outfit-button")
      ?.addEventListener("click", saveActiveOutfit);
    detailContent
      .querySelector("#return-results-button")
      ?.addEventListener("click", closeDetail);
    if (!detailDialog.open) {
      detailDialog.classList.remove("is-visible");
      detailDialog.showModal();
    }
    requestAnimationFrame(() => {
      detailDialog.classList.add("is-visible");
    });
  }

  function saveActiveOutfit() {
    const recent = {
      id: state.activeOutfit.id,
      title: state.activeOutfit.title,
      itemIDs: state.activeOutfit.items.map((item) => item.id),
      occasion: state.occasion.name,
      source: state.activeOutfit.source,
      savedAt: new Date().toISOString()
    };
    localStorage.setItem(STORAGE.recent, JSON.stringify(recent));
    showToast("已保存到最近方案");
    closeDetail();
    renderRecentPlan();
  }

  function renderRecentPlan() {
    const section = document.querySelector("#recent-plan-section");
    const container = document.querySelector("#recent-plan");
    let recent;
    try {
      recent = JSON.parse(localStorage.getItem(STORAGE.recent));
    } catch {
      recent = null;
    }
    if (!recent) {
      section.hidden = true;
      return;
    }
    const items = recent.itemIDs
      .map((id) => state.garments.find((item) => item.id === id))
      .filter(Boolean);
    section.hidden = false;
    container.innerHTML = `
      <article class="outfit-card">
        <div class="outfit-header">
          <div>
            <h2>${escapeHTML(recent.title)}</h2>
            <p class="lead">${escapeHTML(recent.occasion)} · ${escapeHTML(
              recent.source
            )}</p>
          </div>
          <span class="source-badge">已保存</span>
        </div>
        <div class="outfit-photos">
          ${items
            .slice(0, 4)
            .map(
              (item) => `
                <div>
                  <div class="photo-frame">${photoMarkup(item)}</div>
                  <div class="garment-name">${escapeHTML(item.name)}</div>
                </div>
              `
            )
            .join("")}
        </div>
      </article>
    `;
  }

  function generate() {
    const query = occasionInput.value.trim();
    if (!query) {
      showToast("请先输入场合");
      occasionInput.focus();
      return;
    }
    const occasion = engine.resolveOccasion(
      query,
      formalitySelect.value
    );
    formalitySelect.value = occasion.formality;
    const result = engine.createRecommendations(state.garments, occasion);
    occasionResult.hidden = false;
    occasionResult.innerHTML = `
      <p class="eyebrow">理解为 · ${escapeHTML(occasion.source)}</p>
      <h2>${escapeHTML(occasion.name)} · ${escapeHTML(
        engine.FORMALITY_LABEL[occasion.formality]
      )}</h2>
      <p class="lead">重点：${escapeHTML(occasion.keywords.join("、"))}</p>
    `;
    if (result.error) {
      showToast(result.error);
      return;
    }
    state.occasion = occasion;
    state.outfits = result.outfits;
    resultsTitle.textContent = occasion.name;
    resultsNote.textContent = result.countReason;
    renderOutfits();
    go("results");
  }

  function compressImage(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onerror = reject;
      reader.onload = () => {
        const image = new Image();
        image.onerror = reject;
        image.onload = () => {
          const maxEdge = 900;
          const scale = Math.min(1, maxEdge / Math.max(image.width, image.height));
          const canvas = document.createElement("canvas");
          canvas.width = Math.max(1, Math.round(image.width * scale));
          canvas.height = Math.max(1, Math.round(image.height * scale));
          canvas.getContext("2d").drawImage(image, 0, 0, canvas.width, canvas.height);
          resolve(canvas.toDataURL("image/jpeg", 0.82));
        };
        image.src = reader.result;
      };
      reader.readAsDataURL(file);
    });
  }

  document.querySelectorAll("[data-route]").forEach((button) => {
    button.addEventListener("click", () => go(button.dataset.route));
  });

  document.querySelectorAll("[data-preset]").forEach((button) => {
    button.addEventListener("click", () => {
      occasionInput.value = button.dataset.preset;
      occasionInput.focus();
    });
  });

  document.querySelector("#garment-photo").addEventListener("change", async (event) => {
    const file = event.target.files[0];
    state.pendingPhoto = file ? await compressImage(file) : null;
  });

  document.querySelector("#garment-form").addEventListener("submit", (event) => {
    event.preventDefault();
    if (!state.pendingPhoto) {
      showToast("请先选择衣物照片");
      return;
    }
    const name = document.querySelector("#garment-name").value.trim();
    const slot = document.querySelector("#garment-slot").value;
    const colors = document
      .querySelector("#garment-colors")
      .value.split(/[，,、]/)
      .map((value) => value.trim())
      .filter(Boolean);
    const garment = {
      id: `local-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      name,
      slot,
      category: slot,
      colors: colors.length ? colors : ["未标注"],
      formality: Number(document.querySelector("#garment-formality").value),
      photo: state.pendingPhoto
    };
    state.garments.unshift(garment);
    persistGarments();
    event.target.reset();
    state.pendingPhoto = null;
    renderWardrobe();
    renderHome();
    showToast("衣物已保存到本地衣柜");
  });

  document.querySelector("#load-demo-button").addEventListener("click", () => {
    state.garments = structuredClone(data.garments);
    persistGarments();
    renderWardrobe();
    renderHome();
    showToast("已载入演示衣柜");
  });

  document.querySelector("#generate-button").addEventListener("click", generate);
  occasionInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") generate();
  });
  document.querySelector("#close-detail").addEventListener("click", () => {
    closeDetail();
  });
  detailDialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeDetail();
  });

  const contrastButton = document.querySelector("#contrast-button");
  const contrastEnabled = localStorage.getItem(STORAGE.contrast) === "true";
  document.body.dataset.contrast = contrastEnabled ? "high" : "normal";
  contrastButton.setAttribute("aria-pressed", String(contrastEnabled));
  contrastButton.addEventListener("click", () => {
    const enabled = document.body.dataset.contrast !== "high";
    document.body.dataset.contrast = enabled ? "high" : "normal";
    contrastButton.setAttribute("aria-pressed", String(enabled));
    localStorage.setItem(STORAGE.contrast, String(enabled));
  });

  renderWardrobe();
  renderHome();
  go("home");
})();
