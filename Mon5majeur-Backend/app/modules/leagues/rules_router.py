"""
League Rules endpoint — Flutter Rules tab.
Mounted at /api/leagues/rules/

Returns structured, player-facing rules copy, approved by the client
(QA Report #4, Annex A) — different for each game mode (Global vs
Private/Public League) and each language (fr/en). No auth required
(rules are public info).
"""
from fastapi import APIRouter, Query

router = APIRouter(tags=["League Rules"])

# ---------------------------------------------------------------------------
# Approved rules copy — QA Report #4, Annex A. Three sections (Daily
# Schedule, Fantasy Score Formula, Scoring Example) are shared verbatim
# between Global and Private League; the rest differ per mode, per the
# client's own note that the Global League has no named duels, no
# tiebreakers and no playoffs.
# ---------------------------------------------------------------------------

_SCHEDULE_EN = {
    "id": "schedule",
    "title": "Daily Schedule",
    "rules": [
        "09:00 Paris: Final scores computed, standings updated, prices recomputed.",
        "19:00 Paris: Reminder notification if you have no lineup yet.",
        "First tip-off: Lineups lock — no more changes for the night.",
        "Match days follow the US/Eastern NBA calendar (not Paris date).",
    ],
}
_SCHEDULE_FR = {
    "id": "schedule",
    "title": "Déroulé d'une journée",
    "rules": [
        "09h00 Paris : scores finaux calculés, classements mis à jour, prix recalculés.",
        "19h00 Paris : notification de rappel si tu n'as pas encore composé ton 5.",
        "Premier tip-off : verrouillage des compositions — plus aucun changement pour la nuit.",
        "Les journées suivent le calendrier NBA US/Eastern (pas la date de Paris).",
    ],
}
_SCORING_FORMULA_EN = {
    "id": "scoring",
    "title": "Fantasy Score Formula",
    "rules": [
        "Fantasy Score = (Base + Efficiency) × 0.7 (rounded at the end).",
        "Base = Points + Rebounds + Assists + Steals + Blocks − Turnovers.",
        "3-pointer made: +2 pts | missed: −2 pts.",
        "2-pointer made: +1 pt | missed: −1 pt.",
        "Free throw made: +0.5 pt | missed: −0.5 pt.",
        "A player who does not play (DNP) scores 0 FP.",
    ],
}
_SCORING_FORMULA_FR = {
    "id": "scoring",
    "title": "Formule du Fantasy Score",
    "rules": [
        "Fantasy Score = (Base + Efficacité) × 0,7 (arrondi à la fin).",
        "Base = Points + Rebonds + Passes + Interceptions + Contres − Ballons perdus.",
        "Panier à 3 points réussi : +2 pts | manqué : −2 pts.",
        "Panier à 2 points réussi : +1 pt | manqué : −1 pt.",
        "Lancer franc réussi : +0,5 pt | manqué : −0,5 pt.",
        "Un joueur qui ne joue pas (DNP) marque 0 FP.",
    ],
}
_SCORING_EXAMPLE_EN = {
    "id": "scoring_example",
    "title": "Scoring Example",
    "rules": [
        "Example — SGA: 31 pts, 2 reb, 8 ast, 0 stl, 1 blk, 3 to.",
        "2/4 from three (2 made, 2 missed) → +4 − 4 = 0.",
        "8/13 from two (8 made, 5 missed) → +8 − 5 = +3.",
        "9/11 free throws (9 made, 2 missed) → +4.5 − 1 = +3.5.",
        "Base = 31+2+8+0+1−3 = 39. Efficiency = 0+3+3.5 = +6.5.",
        "Fantasy Score = (39 + 6.5) × 0.7 = 45.5 × 0.7 = 32 FP.",
    ],
}
_SCORING_EXAMPLE_FR = {
    "id": "scoring_example",
    "title": "Exemple de calcul",
    "rules": [
        "Exemple — SGA : 31 pts, 2 rbds, 8 pds, 0 int, 1 ctr, 3 blp.",
        "2/4 à 3 points (2 réussis, 2 manqués) → +4 − 4 = 0.",
        "8/13 à 2 points (8 réussis, 5 manqués) → +8 − 5 = +3.",
        "9/11 aux lancers francs (9 réussis, 2 manqués) → +4,5 − 1 = +3,5.",
        "Base = 31+2+8+0+1−3 = 39. Efficacité = 0+3+3,5 = +6,5.",
        "Fantasy Score = (39 + 6,5) × 0,7 = 45,5 × 0,7 = 32 FP.",
    ],
}

_GLOBAL_RULES_EN = [
    {
        "id": "objective",
        "title": "Objective",
        "rules": [
            "Every night, build your starting five with a 100M budget. Your team locks at the first tip-off of the night — no changes possible after that.",
            "Your nightly score = the sum of your 5 players' Fantasy Scores.",
        ],
    },
    _SCHEDULE_EN,
    _SCORING_FORMULA_EN,
    _SCORING_EXAMPLE_EN,
    {
        "id": "rankings",
        "title": "Rankings & Rewards",
        "rules": [
            "Two rankings run in parallel: weekly and monthly. The monthly ranking winner receives an official NBA jersey.",
            "⚠ The NBA season starts on October 22 — not enough games that month for a valid monthly ranking. The first jersey will be awarded to November's winner.",
            "At the end of the season, top players receive trophies, and weekly/monthly winners are featured in the Hall of Fame.",
        ],
    },
]

_GLOBAL_RULES_FR = [
    {
        "id": "objective",
        "title": "Objectif",
        "rules": [
            "Chaque soir, compose ton 5 majeur avec un budget de 100M. Ton équipe se verrouille au premier tip-off de la nuit — impossible de changer après.",
            "Ton score du soir = la somme des Fantasy Score de tes 5 joueurs.",
        ],
    },
    _SCHEDULE_FR,
    _SCORING_FORMULA_FR,
    _SCORING_EXAMPLE_FR,
    {
        "id": "rankings",
        "title": "Classements & récompenses",
        "rules": [
            "Deux classements tournent en parallèle : hebdomadaire et mensuel. Le vainqueur du classement mensuel remporte un maillot NBA officiel.",
            "⚠ La saison NBA démarre le 22 octobre — pas assez de matchs ce mois-là pour un classement mensuel valide. Le premier maillot sera attribué au vainqueur de novembre.",
            "En fin de saison, les meilleurs joueurs remportent des trophées, et les vainqueurs hebdo/mensuels sont mis à l'honneur dans le Hall of Fame.",
        ],
    },
]

_PRIVATE_RULES_EN = [
    {
        "id": "objective",
        "title": "Objective",
        "rules": [
            "Create your league with 4 to 10 friends, by invitation.",
            "Every night, build your starting five with a 100M budget. Your team locks at the first tip-off of the night — no changes possible after that.",
            "Your nightly score = the sum of your 5 players' Fantasy Scores.",
        ],
    },
    _SCHEDULE_EN,
    _SCORING_FORMULA_EN,
    _SCORING_EXAMPLE_EN,
    {
        "id": "duels",
        "title": "Match Day Duels",
        "rules": [
            "Full-season format: you face every member of your league in a home-and-away duel.",
        ],
    },
    {
        "id": "bonuses",
        "title": "Strategic Bonuses",
        "rules": [
            "Unlock strategic bonuses to spice up your duels: Luxury Tax, Chef Curry, 6th Man.",
        ],
    },
    {
        "id": "standings",
        "title": "Standings & Tiebreakers",
        "rules": [
            "In case of a ranking tie, order is determined by: wins → point differential → head-to-head → total points scored → alphabetical order.",
        ],
    },
    {
        "id": "playoffs",
        "title": "Playoffs",
        "rules": [
            "At the end of the regular season, the top 4 qualify for the playoffs: semifinals and final in a best-of-3 (BO3). A home budget bonus is awarded based on your regular season ranking.",
        ],
    },
    {
        "id": "trophies",
        "title": "Trophies",
        "rules": [
            "At the end of the season, the top players in your league receive trophies.",
        ],
    },
]

_PRIVATE_RULES_FR = [
    {
        "id": "objective",
        "title": "Objectif",
        "rules": [
            "Crée ta ligue avec 4 à 10 potes, sur invitation.",
            "Chaque soir, compose ton 5 majeur avec un budget de 100M. Ton équipe se verrouille au premier tip-off de la nuit — impossible de changer après.",
            "Ton score du soir = la somme des Fantasy Score de tes 5 joueurs.",
        ],
    },
    _SCHEDULE_FR,
    _SCORING_FORMULA_FR,
    _SCORING_EXAMPLE_FR,
    {
        "id": "duels",
        "title": "Duels & saison",
        "rules": [
            "Format saison complète : tu affrontes chaque membre de ta ligue en duel, aller-retour (home-and-away).",
        ],
    },
    {
        "id": "bonuses",
        "title": "Bonus stratégiques",
        "rules": [
            "Débloque des bonus stratégiques pour pimenter tes duels : Luxury Tax, Chef Curry, 6ème Homme.",
        ],
    },
    {
        "id": "standings",
        "title": "Classement & départages",
        "rules": [
            "En cas d'égalité au classement, l'ordre est déterminé par : victoires → différentiel de points → confrontation directe → total de points marqués → ordre alphabétique.",
        ],
    },
    {
        "id": "playoffs",
        "title": "Playoffs",
        "rules": [
            "En fin de saison régulière, les 4 meilleurs se qualifient pour les playoffs : demi-finales et finale en BO3 (meilleur des 3 matchs). Un bonus de budget à domicile est accordé selon ton classement en saison régulière.",
        ],
    },
    {
        "id": "trophies",
        "title": "Trophées",
        "rules": [
            "À la fin de la saison, les meilleurs de ta ligue remportent des trophées.",
        ],
    },
]

_RULES_BY_MODE_AND_LANG = {
    ("global", "en"): _GLOBAL_RULES_EN,
    ("global", "fr"): _GLOBAL_RULES_FR,
    # Public leagues run the same duel rules as Private (per the product's
    # own League Types description), so they share the Private copy.
    ("private", "en"): _PRIVATE_RULES_EN,
    ("private", "fr"): _PRIVATE_RULES_FR,
    ("public", "en"): _PRIVATE_RULES_EN,
    ("public", "fr"): _PRIVATE_RULES_FR,
}


@router.get(
    "/leagues/rules/",
    summary="League rules content (Flutter: Rules tab)",
)
async def get_league_rules(
    league_type: str = Query(
        "private",
        pattern="^(global|private|public)$",
        description="Which game mode's rules to return",
    ),
    lang: str = Query(
        "en",
        pattern="^(en|fr)$",
        description="Language of the returned copy",
    ),
) -> dict:
    sections = _RULES_BY_MODE_AND_LANG[(league_type, lang)]
    return {"sections": sections}
