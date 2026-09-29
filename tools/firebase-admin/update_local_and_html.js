const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const serviceAccount = require("../../tmp/firebase/serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function run() {
  const snapshot = await db.collection("feedback").get();
  const list = snapshot.docs.map(doc => {
    const d = doc.data();
    let dateStr = "";
    if (d.creationDate && d.creationDate.toDate) dateStr = d.creationDate.toDate().toISOString();
    else if (d.creationDate) dateStr = new Date(d.creationDate).toISOString();
    else if (d.date) dateStr = new Date(d.date).toISOString();

    const replies = (d.replies || []).map(r => {
      let rDate = "";
      if (r.creationDate && r.creationDate.toDate) rDate = r.creationDate.toDate().toISOString();
      else if (r.creationDate) rDate = new Date(r.creationDate).toISOString();
      else if (r.date) rDate = new Date(r.date).toISOString();
      return {
        authorName: r.authorName || "Utente",
        content: r.content || "",
        isFromDeveloper: !!r.isFromDeveloper,
        date: rDate
      };
    });

    return {
      id: doc.id,
      docId: doc.id,
      title: d.title || "Senza titolo",
      category: d.category || "feature_request",
      status: d.status || "pending",
      authorName: d.authorName || "Anonimo",
      authorId: d.authorId || null,
      votes: d.votes || 0,
      likes: d.likes || 0,
      date: dateStr,
      description: d.description || "",
      replies: replies,
      developerReply: d.developerReply || null
    };
  });

  list.sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));

  fs.writeFileSync("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/all_feedback.json", JSON.stringify(list, null, 2));

  const jsonFeedbacks = JSON.stringify(list);

  const html = `<!DOCTYPE html>
<html lang="it">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SnapTask - Feedback & Commenti</title>
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb { background: rgba(150, 150, 150, 0.3); border-radius: 3px; }
    ::-webkit-scrollbar-thumb:hover { background: rgba(150, 150, 150, 0.5); }
  </style>
</head>
<body class="bg-[var(--background)] text-[var(--foreground)] antialiased min-h-screen p-4 md:p-6 font-sans">
  <div class="max-w-5xl mx-auto space-y-6">
    <header class="bg-[var(--card)] border border-[var(--border)] rounded-2xl p-6 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
      <div>
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 rounded-xl bg-blue-500/10 text-blue-500 flex items-center justify-center font-bold text-xl">
            💬
          </div>
          <div>
            <h1 class="text-xl md:text-2xl font-bold tracking-tight text-[var(--foreground)]">SnapTask Feedback Hub</h1>
            <p class="text-sm text-[var(--muted-foreground)]">Visualizzazione completa dei feedback, commenti e richieste utenti</p>
          </div>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <span id="feedback-count" class="px-3 py-1 rounded-full bg-blue-500/10 text-blue-600 dark:text-blue-400 font-semibold text-sm">
          \${list.length} Feedback
        </span>
      </div>
    </header>

    <div class="bg-[var(--card)] border border-[var(--border)] rounded-2xl p-4 shadow-sm space-y-4">
      <div class="flex flex-col md:flex-row gap-3">
        <div class="relative flex-1">
          <svg class="w-4 h-4 absolute left-3.5 top-3.5 text-[var(--muted-foreground)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
          </svg>
          <input 
            type="text" 
            id="search-input" 
            placeholder="Cerca feedback per titolo, descrizione o autore..." 
            class="w-full pl-10 pr-4 py-2.5 bg-[var(--background)] border border-[var(--border)] rounded-xl text-sm text-[var(--foreground)] placeholder-[var(--placeholder)] focus:outline-none focus:ring-2 focus:ring-blue-500 transition-all"
          />
        </div>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-[var(--border)]">
        <div class="flex flex-wrap items-center gap-1.5 text-xs">
          <span class="text-[var(--muted-foreground)] font-medium mr-1">Categoria:</span>
          <button onclick="setCategory('all')" class="cat-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-blue-600 text-white" data-cat="all">Tutti</button>
          <button onclick="setCategory('bug_report')" class="cat-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]" data-cat="bug_report">🐛 Bug</button>
          <button onclick="setCategory('feature_request')" class="cat-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]" data-cat="feature_request">💡 Feature</button>
          <button onclick="setCategory('general_feedback')" class="cat-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]" data-cat="general_feedback">💬 Generale</button>
        </div>

        <div class="flex flex-wrap items-center gap-1.5 text-xs">
          <span class="text-[var(--muted-foreground)] font-medium mr-1">Stato:</span>
          <button onclick="setStatus('all')" class="status-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-blue-600 text-white" data-status="all">Tutti</button>
          <button onclick="setStatus('pending')" class="status-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]" data-status="pending">⏳ In attesa</button>
          <button onclick="setStatus('completed')" class="status-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]" data-status="completed">✅ Completati</button>
          <button onclick="setStatus('rejected')" class="status-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]" data-status="rejected">❌ Archiviati</button>
        </div>
      </div>
    </div>

    <div id="feedback-list" class="space-y-4"></div>
  </div>

  <script>
    const allData = \${jsonFeedbacks};
    let activeCategory = "all";
    let activeStatus = "all";
    let searchQuery = "";

    function formatDate(dateStr) {
      if (!dateStr) return "N/D";
      const d = new Date(dateStr);
      if (isNaN(d)) return "N/D";
      return d.toLocaleDateString("it-IT", { day: "2-digit", month: "short", year: "numeric" });
    }

    function getCategoryBadge(cat) {
      switch(cat) {
        case "bug_report":
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20">🐛 Bug Report</span>';
        case "feature_request":
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20">💡 Feature Request</span>';
        default:
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20">💬 Feedback</span>';
      }
    }

    function getStatusBadge(status) {
      switch(status) {
        case "completed":
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-500/20">✅ Completato</span>';
        case "in_progress":
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20">⚡ In corso</span>';
        case "rejected":
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-zinc-500/10 text-zinc-500 border border-zinc-500/20">❌ Archiviato</span>';
        case "pending":
        default:
          return '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-md text-xs font-semibold bg-orange-500/10 text-orange-600 dark:text-orange-400 border border-orange-500/20">⏳ In attesa</span>';
      }
    }

    function render() {
      const container = document.getElementById("feedback-list");
      const filtered = allData.filter(item => {
        if (activeCategory !== "all" && item.category !== activeCategory) return false;
        if (activeStatus !== "all" && item.status !== activeStatus) return false;
        if (searchQuery) {
          const q = searchQuery.toLowerCase();
          const matchTitle = (item.title || "").toLowerCase().includes(q);
          const matchDesc = (item.description || "").toLowerCase().includes(q);
          const matchAuthor = (item.authorName || "").toLowerCase().includes(q);
          if (!matchTitle && !matchDesc && !matchAuthor) return false;
        }
        return true;
      });

      document.getElementById("feedback-count").innerText = \`\${filtered.length} Feedback\`;

      if (filtered.length === 0) {
        container.innerHTML = \`
          <div class="bg-[var(--card)] border border-[var(--border)] rounded-2xl p-12 text-center text-[var(--muted-foreground)]">
            <div class="text-4xl mb-3">🔍</div>
            <div class="text-base font-semibold">Nessun feedback trovato</div>
            <div class="text-sm">Prova a modificare i filtri o la ricerca.</div>
          </div>
        \`;
        return;
      }

      container.innerHTML = filtered.map((item, idx) => {
        const repliesHtml = (item.replies && item.replies.length > 0) ? \`
          <div class="mt-4 pt-3 border-t border-[var(--border)] space-y-2">
            <div class="text-xs font-semibold text-[var(--muted-foreground)] uppercase tracking-wider">Risposte (\${item.replies.length})</div>
            \${item.replies.map(r => \`
              <div class="bg-[var(--background)] border border-[var(--border)] rounded-xl p-3 text-sm">
                <div class="flex items-center justify-between mb-1">
                  <span class="font-semibold text-xs \${r.isFromDeveloper ? 'text-blue-500 flex items-center gap-1' : 'text-[var(--foreground)]'}">
                    \${r.isFromDeveloper ? '🛠️ Giovanni (Developer)' : '👤 ' + (r.authorName || 'Utente')}
                  </span>
                  <span class="text-xs text-[var(--muted-foreground)]">\${formatDate(r.date)}</span>
                </div>
                <div class="text-xs text-[var(--foreground)] whitespace-pre-wrap leading-relaxed">\${r.content}</div>
              </div>
            \`).join("")}
          </div>
        \` : (item.developerReply ? \`
          <div class="mt-4 pt-3 border-t border-[var(--border)] space-y-2">
            <div class="text-xs font-semibold text-[var(--muted-foreground)] uppercase tracking-wider">Risposta Sviluppatore</div>
            <div class="bg-[var(--background)] border border-[var(--border)] rounded-xl p-3 text-sm">
              <div class="flex items-center justify-between mb-1">
                <span class="font-semibold text-xs text-blue-500">🛠️ Giovanni (Developer)</span>
              </div>
              <div class="text-xs text-[var(--foreground)] whitespace-pre-wrap leading-relaxed">\${item.developerReply}</div>
            </div>
          </div>
        \` : "");

        return \`
          <div class="bg-[var(--card)] border border-[var(--border)] rounded-2xl p-5 shadow-sm hover:border-blue-500/50 transition-all">
            <div class="flex flex-col md:flex-row md:items-start justify-between gap-3 mb-3">
              <div>
                <div class="flex flex-wrap items-center gap-2 mb-1.5">
                  \${getCategoryBadge(item.category)}
                  \${getStatusBadge(item.status)}
                  <span class="text-xs text-[var(--muted-foreground)] font-medium">📅 \${formatDate(item.date)}</span>
                </div>
                <h3 class="text-base md:text-lg font-bold text-[var(--foreground)] leading-snug">\${item.title}</h3>
                <div class="text-xs text-[var(--muted-foreground)] mt-0.5">Inviato da: <span class="font-medium text-[var(--foreground)]">\${item.authorName || "Anonimo"}</span></div>
              </div>
              <div class="flex items-center gap-2 self-start md:self-auto">
                <div class="flex items-center gap-1.5 px-3 py-1 bg-[var(--background)] border border-[var(--border)] rounded-lg text-xs font-semibold text-[var(--foreground)]">
                  <span>👍</span>
                  <span>\${item.votes || 0}</span>
                </div>
              </div>
            </div>

            <div class="text-sm text-[var(--foreground)]/90 whitespace-pre-wrap bg-[var(--background)]/60 border border-[var(--border)]/70 rounded-xl p-3.5 leading-relaxed">
              \${item.description}
            </div>

            \${repliesHtml}
          </div>
        \`;
      }).join("");
    }

    function setCategory(cat) {
      activeCategory = cat;
      document.querySelectorAll(".cat-btn").forEach(btn => {
        if (btn.dataset.cat === cat) {
          btn.className = "cat-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-blue-600 text-white";
        } else {
          btn.className = "cat-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]";
        }
      });
      render();
    }

    function setStatus(status) {
      activeStatus = status;
      document.querySelectorAll(".status-btn").forEach(btn => {
        if (btn.dataset.status === status) {
          btn.className = "status-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-blue-600 text-white";
        } else {
          btn.className = "status-btn px-3 py-1.5 rounded-lg font-medium transition-all bg-[var(--background)] hover:bg-[var(--sidebar)] text-[var(--muted-foreground)]";
        }
      });
      render();
    }

    document.getElementById("search-input").addEventListener("input", (e) => {
      searchQuery = e.target.value;
      render();
    });

    render();
  </script>
</body>
</html>`;

  fs.writeFileSync("/Users/giovanni/.gemini/antigravity/brain/7096eaa0-4893-4b1b-bf52-079d1e6f5f0a/feedback_dashboard.html", html);
  console.log("Updated feedback_dashboard.html and tmp/all_feedback.json successfully");
}

run().catch(console.error);
