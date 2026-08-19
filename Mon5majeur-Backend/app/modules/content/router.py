"""
Static content & GDPR-required pages (spec §5.3).
Mounted at /api (no /v1 prefix) to match Flutter's expected paths.

⚠️ Placeholder content only. These are NOT real legal/privacy text — a
lawyer or the founder must supply the actual copy before launch. This
module exists so the endpoints are reachable and the app has something
non-empty to render meanwhile.
"""
from __future__ import annotations

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["Static Content (GDPR)"])


class ContentPage(BaseModel):
    title: str
    body: str


class FaqItem(BaseModel):
    question: str
    answer: str


_ABOUT_US = ContentPage(
    title="About Us",
    body="TODO: replace with real About Us copy before launch.",
)

_LEGAL_NOTICES = ContentPage(
    title="Legal Notices",
    body=(
        "TODO: replace with real legal notices (publisher identity, hosting "
        "provider, contact details) before launch — required by French law "
        "(mentions légales)."
    ),
)

_PRIVACY_POLICY = ContentPage(
    title="Privacy Policy",
    body=(
        "TODO: replace with a real GDPR-compliant privacy policy before "
        "launch, covering: what personal data is collected (email, phone/OTP, "
        "pseudo, game history, token purchases), why, how long it's kept, "
        "who it's shared with, and how a user can request access/export/"
        "deletion of their data."
    ),
)

_TERMS_OF_USE = ContentPage(
    title="Terms of Use",
    body=(
        "ENGLISH\n\n"
        "Last updated: August 12, 2026\n\n"
        "1. App publisher\n"
        "MON5MAJEUR, SASU with capital of EUR 1,000, RCS Paris 993 681 915 "
        "(SIRET: 99368191500019), 229 rue Saint-Honore, 75001 Paris, France.\n"
        "President / Publication Director: Robin Martinella\n"
        "Contact: support@mon5majeur.com\n\n"
        "Hosting\n"
        "The Application and associated data are hosted by Amazon Web Services "
        "EMEA SARL, 38 avenue John F. Kennedy, L-1855 Luxembourg (+ MongoDB "
        "Atlas for the database).\n\n"
        "2. Purpose\n"
        "These Terms define the conditions of access to and use of the "
        "Application. By accessing, downloading and/or using it, the User "
        "accepts these Terms without reservation.\n\n"
        "3. Description\n"
        "MON5MAJEUR lets users build virtual teams based on real NBA player "
        "performances, join public and private leagues, view rankings, scores, "
        "and stats, earn and spend Credits, and access free and/or paid "
        "content (in-app purchases, bonuses, rewarded ads). MON5MAJEUR is not "
        "affiliated with the NBA.\n\n"
        "4. Access conditions\n"
        "Free app on the App Store and Google Play. Accessible from age 13 "
        "(parental consent required under 15). In-app purchases are optional "
        "and processed exclusively via the App Store / Google Play.\n\n"
        "5. Account\n"
        "Created via email or Google/Apple account. The User must provide "
        "accurate information and remains responsible for keeping their "
        "credentials confidential. An account inactive for 24 months may be "
        "deleted after notice. Deletion is available anytime via the app or "
        "support@mon5majeur.com.\n\n"
        "6. Virtual Credits and purchases\n"
        "Virtual currency is non-exchangeable, non-transferable, and cannot be "
        "converted into real money. Purchases are processed via App Store / "
        "Google Play. Refunds follow store rules. If the account is deleted, "
        "remaining Credits are lost without compensation.\n\n"
        "7. Advertising and partner content\n"
        "The Application may include advertising and sponsored content. Some "
        "rewards may require optionally watching an ad.\n\n"
        "8. Usage rules and charter\n"
        "Bots, hacks, scripts, bug exploitation, and any action intended to "
        "distort gameplay are prohibited. Usernames, leagues, and content must "
        "remain respectful and lawful. Abuse may lead to warning, restriction, "
        "suspension, or deletion.\n\n"
        "8.5. Public spotlight (Hall of Fame)\n"
        "By taking part in public rankings, the User agrees that their "
        "username and score may be published on MON5MAJEUR official social "
        "media as part of highlighting top rankings.\n\n"
        "9. Contests\n"
        "Free contests with no purchase required. Apple/Google are not "
        "involved. Each contest specifies dates, conditions, number of winners, "
        "selection method, and delivery terms.\n\n"
        "10. Account suspension or deletion\n"
        "Possible in case of fraud, cheating, hacking, breach of these Terms, "
        "or inappropriate content. Deletion is permanent.\n\n"
        "11. Maintenance and availability\n"
        "The Application is provided as is, subject to maintenance, updates, "
        "and interruptions, without compensation.\n\n"
        "12. Intellectual property\n"
        "All elements (code, design, graphics, text, sound) are the exclusive "
        "property of the Publisher. Some data comes from third-party APIs, "
        "without guarantee of accuracy or continuous availability.\n\n"
        "13. Limitation of liability\n"
        "Except in case of gross or willful misconduct, the Publisher is not "
        "liable for network, API, or hosting failures, indirect losses, or "
        "damage resulting from misuse.\n\n"
        "17. Consumer mediation\n"
        "After a prior written complaint that went unresolved to "
        "support@mon5majeur.com, free recourse is available via CM2C, 49 rue "
        "de Ponthieu, 75008 Paris, www.cm2c.net, cm2c@cm2c.net.\n\n"
        "18. Changes to these Terms\n"
        "These Terms may be updated, with notice via the Application. "
        "Continued use after an update constitutes acceptance.\n\n"
        "19. Governing law and disputes\n"
        "Governed by French law. Competent courts are those of the registered "
        "office jurisdiction.\n\n"
        "Contact: support@mon5majeur.com\n\n"
        "FRANCAIS\n\n"
        "Derniere mise a jour : 12 aout 2026\n\n"
        "1. Editeur de l'application\n"
        "MON5MAJEUR, SASU au capital de 1 000 EUR, RCS Paris 993 681 915 "
        "(SIRET : 99368191500019), 229 rue Saint-Honore, 75001 Paris, France.\n"
        "President / Directeur de la publication : Robin Martinella\n"
        "Contact : support@mon5majeur.com\n\n"
        "Hebergement\n"
        "L'Application et les donnees associees sont hebergees par Amazon Web "
        "Services EMEA SARL, 38 avenue John F. Kennedy, L-1855 Luxembourg "
        "(+ MongoDB Atlas pour la base de donnees).\n\n"
        "2. Objet\n"
        "Les presentes CGU definissent les conditions d'acces et "
        "d'utilisation de l'Application. En y accedant, en la telechargeant "
        "et/ou en l'utilisant, l'Utilisateur les accepte sans reserve.\n\n"
        "3. Description\n"
        "MON5MAJEUR permet de creer des equipes virtuelles basees sur les "
        "performances reelles de joueurs NBA, de participer a des ligues "
        "publiques et privees, de consulter classements, scores, statistiques, "
        "de gagner et utiliser des Credits, et d'acceder a des contenus "
        "gratuits et/ou payants.\n\n"
        "4. Conditions d'acces\n"
        "Application gratuite sur App Store et Google Play. Accessible a "
        "partir de 13 ans (accord parental requis en dessous de 15 ans). "
        "Achats integres facultatifs, traites exclusivement via l'App Store / "
        "Google Play.\n\n"
        "5. Compte\n"
        "Creation par email ou compte Google/Apple. L'Utilisateur doit fournir "
        "des informations exactes et reste responsable de la confidentialite "
        "de ses identifiants. Compte inactif 24 mois : suppression possible "
        "apres notification. Suppression a tout moment via l'app ou "
        "support@mon5majeur.com.\n\n"
        "6. Credits virtuels et achats\n"
        "Monnaie virtuelle non echangeable, non transferable, non convertible "
        "en argent reel. Achats traites via App Store / Google Play. "
        "Remboursements regis par les regles des stores. En cas de suppression "
        "de compte, les Credits restants sont perdus sans compensation.\n\n"
        "7. Publicites et contenus partenaires\n"
        "L'Application peut contenir des publicites et contenus sponsorises. "
        "Certaines recompenses peuvent necessiter le visionnage facultatif "
        "d'une publicite.\n\n"
        "8. Regles d'utilisation et charte\n"
        "Sont interdits : bots, hacks, scripts, exploitation de bugs ou toute "
        "action visant a fausser le jeu. Les pseudos, ligues, contenus doivent "
        "rester respectueux et conformes a la loi.\n\n"
        "8.5. Mise en avant publique (Hall of Fame)\n"
        "En participant aux classements publics, l'Utilisateur accepte que "
        "son pseudo et son score puissent etre publies sur les reseaux "
        "sociaux officiels de MON5MAJEUR.\n\n"
        "9. Concours\n"
        "Concours gratuits sans obligation d'achat. Apple/Google n'y "
        "participent en aucun cas. Chaque concours precise dates, conditions, "
        "nombre de gagnants, methode de designation, et modalites de remise.\n\n"
        "10. Suspension ou suppression de compte\n"
        "Possible en cas de fraude, triche, piratage, non-respect des CGU ou "
        "contenu inapproprie. La suppression est definitive.\n\n"
        "11. Maintenance et disponibilite\n"
        "L'Application est fournie en l'etat, sujette a maintenances, mises a "
        "jour et interruptions, sans indemnisation.\n\n"
        "12. Propriete intellectuelle\n"
        "Tous les elements sont la propriete exclusive de l'editeur. "
        "Certaines donnees proviennent d'API tierces, sans garantie "
        "d'exactitude ou de disponibilite continue.\n\n"
        "13. Limitation de responsabilite\n"
        "Sauf faute lourde ou dolosive, l'editeur n'est pas responsable des "
        "pannes reseau, API ou hebergeurs, pertes indirectes, ou dommages lies "
        "a une mauvaise utilisation.\n\n"
        "17. Mediation de la consommation\n"
        "Apres demarche ecrite prealable restee infructueuse aupres de "
        "support@mon5majeur.com, recours gratuit possible aupres de CM2C, 49 "
        "rue de Ponthieu, 75008 Paris, www.cm2c.net, cm2c@cm2c.net.\n\n"
        "18. Modifications des CGU\n"
        "Mise a jour possible, notification via l'Application. L'utilisation "
        "continue apres mise a jour vaut acceptation.\n\n"
        "19. Droit applicable et litiges\n"
        "CGU regies par le droit francais. Tribunaux competents du ressort du "
        "siege social.\n\n"
        "Contact : support@mon5majeur.com"
    ),
)

_FAQS: list[FaqItem] = [
    FaqItem(
        question="TODO: real FAQ content needed",
        answer="Replace this placeholder list with real FAQ entries before launch.",
    ),
]


@router.get("/aboutus/", response_model=ContentPage, summary="About Us (Flutter compat)")
async def about_us() -> ContentPage:
    return _ABOUT_US


@router.get("/legal-notices/", response_model=ContentPage, summary="Legal notices (Flutter compat)")
async def legal_notices() -> ContentPage:
    return _LEGAL_NOTICES


@router.get("/privacy-policies/", response_model=ContentPage, summary="Privacy policy (Flutter compat)")
async def privacy_policy() -> ContentPage:
    return _PRIVACY_POLICY


@router.get("/terms-of-use/", response_model=ContentPage, summary="Terms of use (Flutter compat)")
async def terms_of_use() -> ContentPage:
    return _TERMS_OF_USE


@router.get("/faqs/", response_model=list[FaqItem], summary="FAQ list (Flutter compat)")
async def faqs() -> list[FaqItem]:
    return _FAQS
