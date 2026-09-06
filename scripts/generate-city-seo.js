#!/usr/bin/env node
/**
 * Generates SEO city/country landing pages under web/staedte/
 * and refreshes web/sitemap.xml + web/staedte/index.html
 *
 * Run: node scripts/generate-city-seo.js
 */
"use strict";

const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const OUT_DIR = path.join(ROOT, "web", "staedte");
const SITEMAP = path.join(ROOT, "web", "sitemap.xml");
const BASE = "https://luckystaxiapp.de";

function slugify(name) {
  return name
    .toLowerCase()
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function escJson(s) {
  return JSON.stringify(String(s));
}

/** German cities: [name, landmarks] */
const DE_CITIES = [
  ["Berlin", "Hauptbahnhof, Alexanderplatz, Flughafen BER"],
  ["Hamburg", "Hauptbahnhof, Hafen, Reeperbahn"],
  ["München", "Hauptbahnhof, Marienplatz, Flughafen"],
  ["Köln", "Dom, Hauptbahnhof, Rheinauhafen"],
  ["Frankfurt am Main", "Hauptbahnhof, Flughafen, Bankenviertel"],
  ["Stuttgart", "Hauptbahnhof, Schlossplatz, Messe"],
  ["Düsseldorf", "Hauptbahnhof, Altstadt, Flughafen"],
  ["Leipzig", "Hauptbahnhof, Innenstadt, Messe"],
  ["Dortmund", "Hauptbahnhof, Westfalenpark, Signal Iduna Park"],
  ["Essen", "Hauptbahnhof, Rüttenscheid, Folkwang"],
  ["Bremen", "Hauptbahnhof, Marktplatz, Überseestadt"],
  ["Dresden", "Hauptbahnhof, Altstadt, Neustadt"],
  ["Hannover", "Hauptbahnhof, Opernplatz, Messe"],
  ["Nürnberg", "Hauptbahnhof, Altstadt, Messe"],
  ["Duisburg", "Hauptbahnhof, Innenhafen, Marxloh"],
  ["Bochum", "Hauptbahnhof, Bermuda3eck, Ruhr-Universität"],
  ["Wuppertal", "Hauptbahnhof, Schwebebahn, Elberfeld"],
  ["Bielefeld", "Hauptbahnhof, Altstadt, Universität"],
  ["Bonn", "Hauptbahnhof, Museumsmeile, Beuel"],
  ["Münster", "Hauptbahnhof, Prinzipalmarkt, Aasee"],
  ["Karlsruhe", "Hauptbahnhof, Innenstadt, Messe"],
  ["Mannheim", "Quadrate, Hauptbahnhof, Neckarstadt"],
  ["Augsburg", "Hauptbahnhof, Altstadt, Universität"],
  ["Wiesbaden", "Hauptbahnhof, Kurviertel, Rheingau"],
  ["Mönchengladbach", "Hauptbahnhof, Rheydt, Innenstadt"],
  ["Gelsenkirchen", "Hauptbahnhof, Arena, Schalke"],
  ["Braunschweig", "Hauptbahnhof, Burgplatz, Magniviertel"],
  ["Chemnitz", "Hauptbahnhof, Innenstadt, Technische Universität"],
  ["Kiel", "Hauptbahnhof, Hafen, Förde"],
  ["Aachen", "Hauptbahnhof, Dom, Markt"],
  ["Halle (Saale)", "Hauptbahnhof, Marktplatz, Peißnitz"],
  ["Magdeburg", "Hauptbahnhof, Dom, Elbe"],
  ["Freiburg im Breisgau", "Hauptbahnhof, Altstadt, Universität"],
  ["Krefeld", "Hauptbahnhof, Innenstadt, Uerdingen"],
  ["Lübeck", "Hauptbahnhof, Altstadt, Holstentor"],
  ["Oberhausen", "Hauptbahnhof, Centro, Gasometer"],
  ["Erfurt", "Hauptbahnhof, Domplatz, Altstadt"],
  ["Mainz", "Hauptbahnhof, Altstadt, Rheinufer"],
  ["Rostock", "Hauptbahnhof, Warnemünde, Hafen"],
  ["Kassel", "Hauptbahnhof, Wilhelmshöhe, Documenta"],
  ["Hagen", "Hauptbahnhof, Innenstadt, Haspe"],
  ["Hamm", "Hauptbahnhof, Innenstadt, Maximilianpark"],
  ["Saarbrücken", "Hauptbahnhof, Altstadt, Deutsch-Französische Grenze"],
  ["Mülheim an der Ruhr", "Hauptbahnhof, Innenstadt, Ruhr"],
  ["Potsdam", "Hauptbahnhof, Sanssouci, Altstadt"],
  ["Ludwigshafen", "Bahnhof, Innenstadt, Rheinübergang nach Mannheim"],
  ["Oldenburg", "Hauptbahnhof, Innenstadt, Schloss"],
  ["Osnabrück", "Hauptbahnhof, Altstadt, Universität"],
  ["Leverkusen", "Hauptbahnhof, BayArena, Rheinufer"],
  ["Heidelberg", "Altstadt, Uni, Hauptbahnhof"],
  ["Solingen", "Hauptbahnhof, Innenstadt, Müngstener Brücke"],
  ["Herne", "Hauptbahnhof, Innenstadt, Crange"],
  ["Neuss", "Hauptbahnhof, Innenstadt, Rhein"],
  ["Darmstadt", "Hauptbahnhof, Mathildenhöhe, Universität"],
  ["Paderborn", "Hauptbahnhof, Dom, Universität"],
  ["Regensburg", "Hauptbahnhof, Altstadt, Donau"],
  ["Ingolstadt", "Hauptbahnhof, Altstadt, Audi"],
  ["Würzburg", "Hauptbahnhof, Residenz, Festung"],
  ["Fürth", "Hauptbahnhof, Altstadt, Kärwa"],
  ["Wolfsburg", "Hauptbahnhof, Autostadt, Allerpark"],
  ["Ulm", "Hauptbahnhof, Münster, Donau"],
  ["Heilbronn", "Hauptbahnhof, Neckar, Innenstadt"],
  ["Pforzheim", "Hauptbahnhof, Innenstadt, Schmuckwelten"],
  ["Göttingen", "Hauptbahnhof, Innenstadt, Universität"],
  ["Bottrop", "Hauptbahnhof, Tetraeder, Innenstadt"],
  ["Trier", "Hauptbahnhof, Porta Nigra, Mosel"],
  ["Recklinghausen", "Hauptbahnhof, Altstadt, Ruhrfestspielhaus"],
  ["Reutlingen", "Hauptbahnhof, Marktplatz, Achalm"],
  ["Bremerhaven", "Hauptbahnhof, Havenwelten, Fischereihafen"],
  ["Koblenz", "Hauptbahnhof, Deutsches Eck, Rhein"],
  ["Bergisch Gladbach", "Bahnhof, Innenstadt, Bensberg"],
  ["Jena", "Hauptbahnhof, Innenstadt, Universität"],
  ["Remscheid", "Hauptbahnhof, Innenstadt, Müngsten"],
  ["Erlangen", "Hauptbahnhof, Schlossgarten, Universität"],
  ["Moers", "Bahnhof, Schloss, Innenstadt"],
  ["Siegen", "Hauptbahnhof, Oberstadt, Universität"],
  ["Hildesheim", "Hauptbahnhof, Dom, Markt"],
  ["Salzgitter", "Bahnhof, Lebenstedt, Industrie"],
  ["Cottbus", "Hauptbahnhof, Altmarkt, Universität"],
  ["Gütersloh", "Bahnhof, Innenstadt, Theater"],
  ["Kaiserslautern", "Hauptbahnhof, Betzenberg, Innenstadt"],
  ["Schwerin", "Hauptbahnhof, Schloss, Altstadt"],
  ["Witten", "Bahnhof, Ruhr, Innenstadt"],
  ["Gera", "Hauptbahnhof, Innenstadt, Theater"],
  ["Iserlohn", "Bahnhof, Altstadt, Seilersee"],
  ["Zwickau", "Hauptbahnhof, Innenstadt, Automobilmuseum"],
  ["Düren", "Bahnhof, Innenstadt, Rur"],
  ["Esslingen am Neckar", "Bahnhof, Altstadt, Neckar"],
  ["Ratingen", "Bahnhof, Innenstadt, Angerland"],
  ["Flensburg", "Bahnhof, Hafen, Förde"],
  ["Marl", "Bahnhof, Chemiepark, Innenstadt"],
  ["Lünen", "Bahnhof, Lippe, Innenstadt"],
  ["Villingen-Schwenningen", "Bahnhof, Altstadt, Neckar"],
  ["Konstanz", "Bahnhof, Altstadt, Bodensee"],
  ["Velbert", "Bahnhof, Innenstadt, Neviges"],
  ["Minden", "Bahnhof, Dom, Weser"],
  ["Norderstedt", "Bahnhof, Innenstadt, Hamburg-Umland"],
  ["Delmenhorst", "Bahnhof, Innenstadt, Graft"],
  ["Neumünster", "Bahnhof, Innenstadt, Holstenhallen"],
  ["Bamberg", "Bahnhof, Altstadt, Dom"],
  ["Viersen", "Bahnhof, Innenstadt, Süchteln"],
  ["Rheine", "Bahnhof, Ems, Innenstadt"],
  ["Gladbeck", "Bahnhof, Innenstadt, Wittringen"],
  ["Troisdorf", "Bahnhof, Agger, Innenstadt"],
  ["Speyer", "Dom, Bahnhof, Altstadt"],
  ["Bayreuth", "Bahnhof, Festspielhaus, Innenstadt"],
  ["Castrop-Rauxel", "Bahnhof, Erin, Innenstadt"],
  ["Lüneburg", "Bahnhof, Altstadt, Ilmenau"],
  ["Dorsten", "Bahnhof, Lippe, Schloss"],
  ["Detmold", "Bahnhof, Hermannsdenkmal, Altstadt"],
  ["Arnsberg", "Bahnhof, Altstadt, Ruhr"],
  ["Lüdenscheid", "Bahnhof, Innenstadt, Versetal"],
  ["Landshut", "Bahnhof, Altstadt, Burg Trausnitz"],
  ["Brandenburg an der Havel", "Bahnhof, Dom, Havel"],
  ["Bocholt", "Bahnhof, Innenstadt, Aa"],
  ["Aschaffenburg", "Bahnhof, Schloss, Main"],
  ["Celle", "Bahnhof, Altstadt, Schloss"],
  ["Kempten (Allgäu)", "Bahnhof, Altstadt, Iller"],
  ["Fulda", "Bahnhof, Dom, Barockviertel"],
  ["Dinslaken", "Bahnhof, Innenstadt, Rotbach"],
  ["Rüsselsheim am Main", "Bahnhof, Opel, Main"],
  ["Kerpen", "Bahnhof, Innenstadt, Sindorf"],
  ["Stolberg (Rheinland)", "Bahnhof, Altstadt, Kupferhof"],
  ["Rosenheim", "Bahnhof, Innenstadt, Mangfall"],
  ["Neubrandenburg", "Bahnhof, Tollensesee, Altstadt"],
  ["Herten", "Bahnhof, Schloss, Innenstadt"],
  ["Wesel", "Bahnhof, Rhein, Zitadelle"],
  ["Stralsund", "Bahnhof, Altstadt, Hafen"],
  ["Offenburg", "Bahnhof, Innenstadt, Kinzig"],
  ["Friedrichshafen", "Bahnhof, Bodensee, Messe"],
  ["Görlitz", "Bahnhof, Altstadt, Neiße"],
  ["Hilden", "Bahnhof, Innenstadt, Itter"],
  ["Sankt Augustin", "Bahnhof, Hochschule, Sieg"],
  ["Euskirchen", "Bahnhof, Innenstadt, Erft"],
  ["Schwäbisch Gmünd", "Bahnhof, Altstadt, Rems"],
  ["Grevenbroich", "Bahnhof, Erft, Innenstadt"],
  ["Neu-Ulm", "Bahnhof, Donau, Innenstadt"],
  ["Hürth", "Bahnhof, Efferen, Rhein-Erft"],
  ["Hameln", "Bahnhof, Rattenfänger, Weser"],
  ["Baden-Baden", "Bahnhof, Kurhaus, Lichtentaler Allee"],
  ["Bad Homburg vor der Höhe", "Bahnhof, Kurpark, Schloss"],
  ["Schweinfurt", "Bahnhof, Main, Innenstadt"],
  ["Neustadt an der Weinstraße", "Bahnhof, Altstadt, Weinstraße"],
  ["Passau", "Bahnhof, Dreiflüssestadt, Dom"],
  ["Wetzlar", "Bahnhof, Altstadt, Lahn"],
  ["Cuxhaven", "Bahnhof, Hafen, Wattenmeer"],
  ["Pulheim", "Bahnhof, Brauweiler, Rhein-Erft"],
  ["Ravensburg", "Bahnhof, Altstadt, Oberschwaben"],
  ["Kleve", "Bahnhof, Schwanenburg, Niederrhein"],
  ["Gießen", "Bahnhof, Universität, Lahn"],
  ["Unna", "Bahnhof, Hellweg, Innenstadt"],
  ["Goslar", "Bahnhof, Altstadt, Kaiserpfalz"],
];

/** Neighbor / Europe: country pages + major cities */
const COUNTRIES = [
  {
    slug: "deutschland",
    name: "Deutschland",
    country: "DE",
    type: "country",
    landmarks: "bundesweit — Großstädte und Regionen",
    note: "taxameter",
  },
  {
    slug: "frankreich",
    name: "Frankreich",
    country: "FR",
    type: "country",
    landmarks: "Paris, Straßburg, Grenzregion",
    note: "local",
  },
  {
    slug: "spanien",
    name: "Spanien",
    country: "ES",
    type: "country",
    landmarks: "Madrid, Barcelona, Costa",
    note: "local",
  },
  {
    slug: "luxemburg",
    name: "Luxemburg",
    country: "LU",
    type: "country",
    landmarks: "Luxemburg-Stadt, Grenzverkehr",
    note: "local",
  },
  {
    slug: "belgien",
    name: "Belgien",
    country: "BE",
    type: "country",
    landmarks: "Brüssel, Antwerpen, Lüttich",
    note: "local",
  },
  {
    slug: "niederlande",
    name: "Niederlande",
    country: "NL",
    type: "country",
    landmarks: "Amsterdam, Rotterdam, Grenzregion",
    note: "local",
  },
  {
    slug: "oesterreich",
    name: "Österreich",
    country: "AT",
    type: "country",
    landmarks: "Wien, Salzburg, Innsbruck",
    note: "local",
  },
  {
    slug: "schweiz",
    name: "Schweiz",
    country: "CH",
    type: "country",
    landmarks: "Zürich, Basel, Genf",
    note: "local",
  },
  {
    slug: "polen",
    name: "Polen",
    country: "PL",
    type: "country",
    landmarks: "Warschau, Krakau, Grenzregion",
    note: "local",
  },
  {
    slug: "tschechien",
    name: "Tschechien",
    country: "CZ",
    type: "country",
    landmarks: "Prag, Brünn, Grenzregion",
    note: "local",
  },
  {
    slug: "daenemark",
    name: "Dänemark",
    country: "DK",
    type: "country",
    landmarks: "Kopenhagen, Grenzregion",
    note: "local",
  },
  {
    slug: "italien",
    name: "Italien",
    country: "IT",
    type: "country",
    landmarks: "Rom, Mailand, Südtirol-Nähe",
    note: "local",
  },
  {
    slug: "finnland",
    name: "Finnland",
    country: "FI",
    type: "country",
    landmarks: "Helsinki, Tampere, Turku",
    note: "local",
  },
  {
    slug: "schweden",
    name: "Schweden",
    country: "SE",
    type: "country",
    landmarks: "Stockholm, Göteborg, Malmö",
    note: "local",
  },
  {
    slug: "norwegen",
    name: "Norwegen",
    country: "NO",
    type: "country",
    landmarks: "Oslo, Bergen, Grenzregion",
    note: "local",
  },
  {
    slug: "portugal",
    name: "Portugal",
    country: "PT",
    type: "country",
    landmarks: "Lissabon, Porto, Algarve",
    note: "local",
  },
  {
    slug: "irland",
    name: "Irland",
    country: "IE",
    type: "country",
    landmarks: "Dublin, Cork, Galway",
    note: "local",
  },
  {
    slug: "vereinigtes-koenigreich",
    name: "Vereinigtes Königreich",
    country: "GB",
    type: "country",
    landmarks: "London, Manchester, Edinburgh",
    note: "local",
  },
];

const FOREIGN_CITIES = [
  ["Paris", "FR", "Frankreich", "Garde du Nord, Tour Eiffel, Flughäfen"],
  ["Straßburg", "FR", "Frankreich", "Bahnhof, Altstadt, Europaviertel"],
  ["Lyon", "FR", "Frankreich", "Part-Dieu, Altstadt, Flughafen"],
  ["Marseille", "FR", "Frankreich", "Bahnhof Saint-Charles, Hafen, Altstadt"],
  ["Madrid", "ES", "Spanien", "Atocha, Zentrum, Flughafen"],
  ["Barcelona", "ES", "Spanien", "Sants, Ramblas, Flughafen"],
  ["Valencia", "ES", "Spanien", "Bahnhof, Zentrum, Hafen"],
  ["Luxemburg-Stadt", "LU", "Luxemburg", "Bahnhof, Kirchberg, Altstadt"],
  ["Brüssel", "BE", "Belgien", "Midi, Europaviertel, Altstadt"],
  ["Antwerpen", "BE", "Belgien", "Centraal, Hafen, Altstadt"],
  ["Amsterdam", "NL", "Niederlande", "Centraal, Schiphol, Innenstadt"],
  ["Rotterdam", "NL", "Niederlande", "Centraal, Hafen, Innenstadt"],
  ["Maastricht", "NL", "Niederlande", "Bahnhof, Altstadt, Grenzverkehr"],
  ["Wien", "AT", "Österreich", "Hauptbahnhof, Innere Stadt, Flughafen"],
  ["Salzburg", "AT", "Österreich", "Hauptbahnhof, Altstadt, Flughafen"],
  ["Innsbruck", "AT", "Österreich", "Hauptbahnhof, Altstadt, Flughafen"],
  ["Zürich", "CH", "Schweiz", "Hauptbahnhof, Flughafen, Innenstadt"],
  ["Basel", "CH", "Schweiz", "Bahnhof SBB, Messe, Rhein"],
  ["Genf", "CH", "Schweiz", "Cornavin, Flughafen, See"],
  ["Warschau", "PL", "Polen", "Zentralbahnhof, Altstadt, Flughafen"],
  ["Krakau", "PL", "Polen", "Hauptbahnhof, Altstadt, Flughafen"],
  ["Prag", "CZ", "Tschechien", "Hauptbahnhof, Altstadt, Flughafen"],
  ["Kopenhagen", "DK", "Dänemark", "Hauptbahnhof, Innenstadt, Flughafen"],
  ["Mailand", "IT", "Italien", "Centrale, Dom, Flughäfen"],
  ["Rom", "IT", "Italien", "Termini, Zentrum, Flughäfen"],
  ["Helsinki", "FI", "Finnland", "Hauptbahnhof, Hafen, Flughafen"],
  ["Stockholm", "SE", "Schweden", "Central, Gamla Stan, Flughafen"],
  ["Oslo", "NO", "Norwegen", "Central, Innenstadt, Flughafen"],
  ["Lissabon", "PT", "Portugal", "Santa Apolónia, Zentrum, Flughafen"],
  ["Dublin", "IE", "Irland", "Heuston, Zentrum, Flughafen"],
  ["London", "GB", "Vereinigtes Königreich", "Kings Cross, Zentrum, Flughäfen"],
];

const SPECIAL = {
  speyer: {
    guest:
      "Ob vom Hauptbahnhof zur Maximilianstraße, vom Dom zum Technik-Museum oder spät vom Rheinufer nach Hause: Mit Luckys Taxi App gibst du die Abholadresse in Speyer ein und buchst online. Der Fahrpreis steht auf dem Taxameter — du zahlst bar beim Fahrer, ohne Reservierungsgebühr in der App.",
    operator:
      "Code & Grow (Firmensitz Speyer, Asternweg 21) betreibt die Plattform Luckys Taxi App. Für lokale Betriebe bedeutet das: Fahrgäste bestellen unter Ihrem Namen, Sie sehen Buchungen in der Browser-Leitstelle und verteilen sie an Ihre Fahrer — parallel zur städtischen Zentrale, nicht als Ersatz.",
    faqExtra: {
      q: "Sitzt Code & Grow in Speyer?",
      a: "Ja — Firmensitz Asternweg 21, 67346 Speyer. Code & Grow ist der Software-Anbieter hinter Luckys Taxi App, kein Taxi-Betrieb. Details im Impressum.",
    },
    orgAddress: true,
  },
  mannheim: {
    guest:
      "Abend in den Quadraten, Anschluss am Hauptbahnhof oder Fahrt nach Käfertal und Feudenheim: In der Buchung trägst du die Mannheimer Adresse ein und wählst Sofort oder Termin. Der Preis kommt vom Taxameter — bar beim Fahrer, ohne App-Gebühr für die Reservierung.",
    operator:
      "In Mannheim kennt man die große Taxizentrale — und trotzdem fehlt vielen Betrieben ein eigener digitaler Kanal. Luckys Taxi App bringt Online-Buchung, Leitstellen-Ansicht und QR-Code unter Ihrem Firmennamen. Zusatzaufträge von Stammkunden und Hotels, ohne die Zentrale abzuschalten.",
  },
};

function buildLocations() {
  const seen = new Set();
  const list = [];

  function add(loc) {
    if (seen.has(loc.slug)) return;
    seen.add(loc.slug);
    list.push(loc);
  }

  for (const c of COUNTRIES) {
    add({
      slug: c.slug,
      name: c.name,
      country: c.country,
      countryName: c.name,
      type: "country",
      landmarks: c.landmarks,
      note: c.note,
    });
  }

  for (const [name, landmarks] of DE_CITIES) {
    const slug = slugify(name.replace(/\(.*?\)/g, "").trim());
    add({
      slug,
      name,
      country: "DE",
      countryName: "Deutschland",
      type: "city",
      landmarks,
      note: "taxameter",
    });
  }

  for (const [name, country, countryName, landmarks] of FOREIGN_CITIES) {
    add({
      slug: slugify(name),
      name,
      country,
      countryName,
      type: "city",
      landmarks,
      note: "local",
    });
  }

  return list.sort((a, b) => {
    if (a.country !== b.country) {
      if (a.country === "DE") return -1;
      if (b.country === "DE") return 1;
      return a.countryName.localeCompare(b.countryName, "de");
    }
    if (a.type !== b.type) return a.type === "country" ? -1 : 1;
    return a.name.localeCompare(b.name, "de");
  });
}

function payPhrase(loc) {
  if (loc.note === "taxameter") {
    return "Der Fahrpreis steht auf dem Taxameter — Zahlung bar beim Fahrer, ohne Reservierungsgebühr in der App.";
  }
  return "Der Preis richtet sich nach dem lokalen Tarif bzw. Taxameter vor Ort — Zahlung nach Absprache mit dem Partner-Betrieb.";
}

function guestText(loc) {
  if (SPECIAL[loc.slug]?.guest) return SPECIAL[loc.slug].guest;
  if (loc.type === "country") {
    return `Luckys Taxi App verbindet Fahrgäste und Taxi-Betriebe in ${loc.name}. Ob ${loc.landmarks}: Du gibst die Abholadresse online ein und buchst über die Plattform. ${payPhrase(loc)} Wo noch kein Partner aktiv ist, wächst das Netz mit neuen Betrieben — Anfragen sind willkommen.`;
  }
  return `In ${loc.name} (${loc.countryName}) buchst du online: ${loc.landmarks}. Abholadresse und Zeit angeben — optional Luckys Taxi App auf den Home-Bildschirm legen. ${payPhrase(loc)}`;
}

function operatorText(loc) {
  if (SPECIAL[loc.slug]?.operator) return SPECIAL[loc.slug].operator;
  if (loc.type === "country") {
    return `Taxi-Betriebe in ${loc.name} holen sich mit Luckys Taxi App einen eigenen digitalen Kanal: Online-Buchung, Browser-Leitstelle und QR-Code unter Ihrem Firmennamen — ab 49 €/Monat, monatlich kündbar. Ideal für Stammkunden, Hotels und Firmenfahrten neben Funk und Telefon.`;
  }
  return `Für Taxi-Betriebe in ${loc.name}: Fahrgäste bestellen unter Ihrem Namen. Sie sehen Anfragen in der Leitstelle und weisen Ihre Fahrer zu — parallel zur klassischen Zentrale. Starter ab 49 €/Monat, Business 99 €/Monat, monatlich kündbar.`;
}

function heroSub(loc) {
  if (loc.type === "country") {
    return `Online bestellen in ${loc.name} (${loc.landmarks}) — oder als Betrieb Ihre eigene digitale Leitstelle nutzen.`;
  }
  return `Online bestellen rund um ${loc.landmarks} — oder als Betrieb Ihre eigene digitale Leitstelle nutzen.`;
}

function relatedLinks(loc, all) {
  const sameCountry = all.filter(
    (x) => x.country === loc.country && x.slug !== loc.slug
  );
  const countries = all.filter((x) => x.type === "country" && x.slug !== loc.slug);
  const picks = [];
  for (const x of sameCountry) {
    if (picks.length >= 8) break;
    picks.push(x);
  }
  if (picks.length < 6) {
    for (const x of countries) {
      if (picks.length >= 8) break;
      if (!picks.find((p) => p.slug === x.slug)) picks.push(x);
    }
  }
  return picks;
}

function renderPage(loc, all) {
  const url = `${BASE}/staedte/${loc.slug}.html`;
  const title =
    loc.type === "country"
      ? `Taxi bestellen in ${loc.name} | Luckys Taxi App`
      : `Taxi bestellen in ${loc.name} | Luckys Taxi App`;
  const desc =
    loc.type === "country"
      ? `Taxi in ${loc.name} online bestellen — ${loc.landmarks}. Für Taxi-Betriebe: Leitstelle und Fahrgast-App ab 49 €/Monat.`
      : `Taxi in ${loc.name} online bestellen — ${loc.landmarks}. Bar bzw. nach lokalem Tarif. Taxi-Betriebe: eigene Leitstelle ab 49 €/Monat.`;

  const areaType = loc.type === "country" ? "Country" : "City";
  const orgBlock = SPECIAL[loc.slug]?.orgAddress
    ? `,
          "address": {
            "@type": "PostalAddress",
            "streetAddress": "Asternweg 21",
            "addressLocality": "Speyer",
            "postalCode": "67346",
            "addressCountry": "DE"
          }`
    : "";

  const faqExtra = SPECIAL[loc.slug]?.faqExtra;
  const faqs = [
    {
      q: `Wie bestelle ich ein Taxi in ${loc.name}?`,
      a: `Auf luckystaxiapp.de/book.html Abholadresse in ${loc.name} und Zeit angeben. ${payPhrase(loc)}`,
    },
    {
      q: `Was kostet Luckys Taxi App für Betriebe in ${loc.name}?`,
      a: "Starter 49 €/Monat oder Business 99 €/Monat, monatlich kündbar — inkl. Online-Buchung, Leitstelle und QR-Code.",
    },
  ];
  if (faqExtra) faqs.splice(1, 0, faqExtra);
  else
    faqs.splice(1, 0, {
      q:
        loc.type === "country"
          ? `Gibt es schon Partner in ganz ${loc.name}?`
          : `Gibt es Partner-Taxis in ${loc.name}?`,
      a: `Die Plattform wächst mit angeschlossenen Betrieben. Wo ein Partner aktiv ist, läuft die Buchung unter dessen Namen — neue Betriebe können sich jederzeit anmelden.`,
    });

  const related = relatedLinks(loc, all);
  const relatedHtml = related
    .map((r) => `<li><a href="${esc(r.slug)}.html">${esc(r.name)}</a></li>`)
    .join("\n        ");

  const schemaFaqs = faqs
    .map(
      (f) => `{
            "@type": "Question",
            "name": ${escJson(f.q)},
            "acceptedAnswer": {
              "@type": "Answer",
              "text": ${escJson(f.a)}
            }
          }`
    )
    .join(",\n          ");

  const faqHtml = faqs
    .map(
      (f) => `<article>
        <h3>${esc(f.q)}</h3>
        <p>${esc(f.a)}</p>
      </article>`
    )
    .join("\n      ");

  return `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${esc(title)}</title>
  <meta name="description" content="${esc(desc)}">
  <link rel="canonical" href="${esc(url)}">
  <meta name="robots" content="index,follow">
  <meta name="theme-color" content="#1c304f">
  <meta property="og:title" content="${esc(title)}">
  <meta property="og:description" content="${esc(desc)}">
  <meta property="og:type" content="website">
  <meta property="og:locale" content="de_DE">
  <meta property="og:url" content="${esc(url)}">
  <meta property="og:image" content="${BASE}/icon-taxi-512.png">
  <link rel="icon" type="image/png" href="../icon-taxi-192.png">
  <link rel="stylesheet" href="../styles.css">
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "WebPage",
        "name": ${escJson(`Taxi bestellen in ${loc.name}`)},
        "url": ${escJson(url)},
        "description": ${escJson(desc)}
      },
      {
        "@type": "Service",
        "name": ${escJson(`Luckys Taxi App — ${loc.name}`)},
        "serviceType": "Taxi-Buchung und Taxi-Leitstelle",
        "provider": {
          "@type": "Organization",
          "name": "Code & Grow",
          "url": "${BASE}/"${orgBlock}
        },
        "areaServed": { "@type": "${areaType}", "name": ${escJson(loc.name)} },
        "url": ${escJson(url)}
      },
      {
        "@type": "FAQPage",
        "mainEntity": [
          ${schemaFaqs}
        ]
      }
    ]
  }
  </script>
  <script src="../analytics.js" defer></script>
</head>
<body class="city-page">
  <header class="city-hero">
    <div class="city-hero-inner">
      <p class="city-brand"><a href="../index.html">Luckys Taxi App</a></p>
      <h1>Taxi in ${esc(loc.name)}</h1>
      <p class="city-sub">${esc(heroSub(loc))}</p>
      <div class="city-ctas">
        <a class="btn" href="../book.html">Taxi bestellen</a>
        <a class="btn secondary" href="../onboard.html">Für Betriebe</a>
      </div>
    </div>
  </header>

  <main class="wrap city-main">
    <div class="city-split">
      <section class="city-block">
        <h2>Für Fahrgäste in ${esc(loc.name)}</h2>
        <p>${esc(guestText(loc))}</p>
        <p><a class="btn" href="../book.html">Jetzt bestellen</a></p>
      </section>
      <section class="city-block">
        <h2>Für Taxi-Betriebe in ${esc(loc.name)}</h2>
        <p>${esc(operatorText(loc))}</p>
        <p><a class="btn secondary" href="../onboard.html">Partner werden ab 49 €</a></p>
      </section>
    </div>

    <section class="city-faq">
      <h2>Fragen zu ${esc(loc.name)}</h2>
      ${faqHtml}
    </section>

    <nav class="city-nav" aria-label="Weitere Orte">
      <h2>Weitere Orte</h2>
      <ul>
        <li><a href="index.html">Alle Orte</a></li>
        ${relatedHtml}
      </ul>
    </nav>
  </main>

  <footer class="site-footer">
    <nav>
      <a href="../index.html">Start</a>
      <a href="index.html">Städte &amp; Länder</a>
      <a href="../book.html">Taxi bestellen</a>
      <a href="../onboard.html">Partner werden</a>
      <a href="../impressum.html">Impressum</a>
      <a href="../datenschutz.html">Datenschutz</a>
    </nav>
    <p>© 2026 Code &amp; Grow · ${esc(loc.name)}</p>
  </footer>
</body>
</html>
`;
}

function renderHub(all) {
  const byCountry = new Map();
  for (const loc of all) {
    const key = loc.countryName;
    if (!byCountry.has(key)) byCountry.set(key, []);
    byCountry.get(key).push(loc);
  }

  const sections = [];
  const deFirst = [...byCountry.entries()].sort((a, b) => {
    if (a[0] === "Deutschland") return -1;
    if (b[0] === "Deutschland") return 1;
    return a[0].localeCompare(b[0], "de");
  });

  for (const [countryName, locs] of deFirst) {
    const items = locs
      .map((l) => {
        const label =
          l.type === "country" ? `<strong>${esc(l.name)}</strong> (Land)` : esc(l.name);
        return `<li><a href="${esc(l.slug)}.html">${label}</a></li>`;
      })
      .join("\n        ");
    sections.push(`<section class="city-block" style="margin-bottom:1.25rem">
      <h2>${esc(countryName)}</h2>
      <ul class="cities-seo-list">
        ${items}
      </ul>
    </section>`);
  }

  return `<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Taxi bestellen: Städte &amp; Länder | Luckys Taxi App</title>
  <meta name="description" content="Taxi online bestellen in Deutschland und Nachbarländern. Lokale Seiten für Fahrgäste und Taxi-Betriebe — Luckys Taxi App.">
  <link rel="canonical" href="${BASE}/staedte/">
  <meta name="robots" content="index,follow">
  <meta name="theme-color" content="#ffcc00">
  <meta property="og:title" content="Taxi bestellen: Städte &amp; Länder | Luckys Taxi App">
  <meta property="og:description" content="Deutschland und Europa: lokale Taxi-Seiten für Fahrgäste und Betriebe.">
  <meta property="og:type" content="website">
  <meta property="og:url" content="${BASE}/staedte/">
  <meta property="og:image" content="${BASE}/icon-taxi-512.png">
  <link rel="icon" type="image/png" href="../icon-taxi-192.png">
  <link rel="stylesheet" href="../styles.css">
  <script src="../analytics.js" defer></script>
</head>
<body class="city-page cities-hub">
  <header class="city-hero">
    <div class="city-hero-inner">
      <p class="city-brand"><a href="../index.html">Luckys Taxi App</a></p>
      <h1>Städte &amp; Länder</h1>
      <p class="city-sub">Deutschland bundesweit und Nachbarländer — Seiten für Fahrgäste und Taxi-Betriebe.</p>
      <div class="city-ctas">
        <a class="btn" href="../book.html">Taxi bestellen</a>
        <a class="btn secondary" href="../onboard.html">Plattform mieten</a>
      </div>
    </div>
  </header>
  <main class="wrap city-main">
    <p class="lead">Wähle deinen Ort. Jede Seite erklärt die Buchung für Fahrgäste und die Software für Betriebe.</p>
    ${sections.join("\n    ")}
  </main>
  <footer class="site-footer">
    <nav>
      <a href="../index.html">Start</a>
      <a href="../book.html">Taxi bestellen</a>
      <a href="../onboard.html">Plattform mieten</a>
      <a href="../impressum.html">Impressum</a>
      <a href="../datenschutz.html">Datenschutz</a>
    </nav>
    <p>© 2026 Code &amp; Grow</p>
  </footer>
</body>
</html>
`;
}

function writeSitemap(all) {
  const staticUrls = [
    ["/", "weekly", "1.0"],
    ["/book.html", "weekly", "0.9"],
    ["/onboard.html", "monthly", "0.8"],
    ["/staedte/", "weekly", "0.85"],
    ["/impressum.html", "yearly", "0.3"],
    ["/datenschutz.html", "yearly", "0.3"],
    ["/agb.html", "yearly", "0.3"],
  ];

  const urls = [
    ...staticUrls.map(
      ([loc, freq, prio]) => `  <url>
    <loc>${BASE}${loc}</loc>
    <changefreq>${freq}</changefreq>
    <priority>${prio}</priority>
  </url>`
    ),
    ...all.map((loc) => {
      const prio = loc.type === "country" ? "0.75" : loc.country === "DE" ? "0.7" : "0.55";
      return `  <url>
    <loc>${BASE}/staedte/${loc.slug}.html</loc>
    <changefreq>monthly</changefreq>
    <priority>${prio}</priority>
  </url>`;
    }),
  ];

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.join("\n")}
</urlset>
`;
}

function main() {
  const all = buildLocations();
  fs.mkdirSync(OUT_DIR, { recursive: true });

  // Remove old generated HTML (keep nothing stale)
  for (const f of fs.readdirSync(OUT_DIR)) {
    if (f.endsWith(".html")) fs.unlinkSync(path.join(OUT_DIR, f));
  }

  for (const loc of all) {
    fs.writeFileSync(path.join(OUT_DIR, `${loc.slug}.html`), renderPage(loc, all), "utf8");
  }
  fs.writeFileSync(path.join(OUT_DIR, "index.html"), renderHub(all), "utf8");
  fs.writeFileSync(SITEMAP, writeSitemap(all), "utf8");

  // Manifest for transparency
  fs.writeFileSync(
    path.join(OUT_DIR, "locations.generated.json"),
    JSON.stringify(
      all.map((l) => ({ slug: l.slug, name: l.name, country: l.country, type: l.type })),
      null,
      2
    ),
    "utf8"
  );

  console.log(`Generated ${all.length} location pages + hub + sitemap.`);
}

main();
