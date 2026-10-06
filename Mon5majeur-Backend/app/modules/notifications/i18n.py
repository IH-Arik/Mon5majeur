"""French text of the notifications (QA #9 2.6).

The backend composes notifications in English; users whose language is French
get the translated text, in the informal "tu" tone, both in the in-app list
and in the push. Messages with a name or a reason inside are matched by
pattern. Unknown text is returned unchanged, so a new notification is never
lost, it is just English until a rule is added here.
"""
from __future__ import annotations

import re

_FIXED = {
    "Don't forget your team!": "N'oublie pas ton équipe !",
    "Don't forget your lineup tonight 🏀": "N'oublie pas de composer ton équipe ce soir 🏀",
    "Results are in": "Les résultats sont tombés",
    "🏀 Standings updated — come see where you rank.": "🏀 Classement mis à jour : viens voir où tu te classes.",
    "🏆 Top 8 this week!": "🏆 Top 8 de la semaine !",
    "You finished in the Global League's weekly Top 8 — a bonus was added to your inventory.": (
        "Tu as terminé dans le Top 8 hebdomadaire de la Ligue Globale : "
        "un bonus a été ajouté à ton inventaire."
    ),
    "🏆 You won the month!": "🏆 Tu as gagné le mois !",
    "You're #1 in the Global League this month — an NBA jersey is on its way. We'll be in touch.": (
        "Tu es n°1 de la Ligue Globale ce mois-ci : un maillot NBA est en route. "
        "On revient vers toi."
    ),
    "🏆 You won the league!": "🏆 Tu as gagné la ligue !",
}

# (pattern, French template using the pattern's groups as {1}, {2} ...)
_PATTERNS = [
    (r"^Tonight you face (.+)\. Don't let them trash-talk you — set your lineup 🔥$",
     "Ce soir, tu affrontes {1}. Ne les laisse pas te chambrer : compose ton équipe 🔥"),
    (r"^Tonight you face (.+) — set your lineup 🏀$",
     "Ce soir, tu affrontes {1} : compose ton équipe 🏀"),
    (r"^🏀 Your duel vs (.+) is over — come see the result\.$",
     "🏀 Ton duel contre {1} est terminé : viens voir le résultat."),
    (r"^(.+) is OUT$", "{1} est absent (OUT)"),
    (r"^Reason: (.+)\. Update your lineup before tip-off\.$",
     "Motif : {1}. Mets à jour ta composition avant le coup d'envoi."),
    (r"^You're the champion of (.+)\. Congratulations!$",
     "Tu es le champion de {1}. Félicitations !"),
]


def _fr(text: str) -> str:
    if text in _FIXED:
        return _FIXED[text]
    for pattern, template in _PATTERNS:
        m = re.match(pattern, text)
        if m:
            out = template
            for i, group in enumerate(m.groups(), start=1):
                out = out.replace("{%d}" % i, group)
            return out
    return text


def localize(title: str, body: str, language: str | None) -> tuple[str, str]:
    """(title, body) in the user's language."""
    if (language or "en").lower().startswith("fr"):
        return _fr(title), _fr(body)
    return title, body
