"""QA #9 2.6: notifications reach French users in French ("tu" tone)."""
from app.modules.notifications.i18n import localize


def test_french_fixed_texts():
    assert localize("Don't forget your team!", "Don't forget your lineup tonight 🏀", "fr") == (
        "N'oublie pas ton équipe !",
        "N'oublie pas de composer ton équipe ce soir 🏀",
    )
    assert localize("🏆 Top 8 this week!", "x", "fr")[0] == "🏆 Top 8 de la semaine !"


def test_french_texts_with_a_name_inside():
    t, b = localize(
        "Don't forget your team!", "Tonight you face Rob1 — set your lineup 🏀", "fr"
    )
    assert b == "Ce soir, tu affrontes Rob1 : compose ton équipe 🏀"
    t, b = localize("LeBron James is OUT", "Reason: Ankle. Update your lineup before tip-off.", "fr")
    assert (t, b) == (
        "LeBron James est absent (OUT)",
        "Motif : Ankle. Mets à jour ta composition avant le coup d'envoi.",
    )
    assert localize("x", "You're the champion of Mes Potes. Congratulations!", "fr")[1] == (
        "Tu es le champion de Mes Potes. Félicitations !"
    )


def test_english_and_unknown_are_unchanged():
    assert localize("Results are in", "b", "en") == ("Results are in", "b")
    assert localize("Results are in", "b", None) == ("Results are in", "b")
    assert localize("Something new", "Unlisted text", "fr") == ("Something new", "Unlisted text")
