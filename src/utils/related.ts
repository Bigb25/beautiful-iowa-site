import type { CollectionEntry } from "astro:content";

/* "Continue exploring" matching for the Beautiful Iowa article pages.
   Deterministic and build-time only: exact name matches first, then
   same-county matches, each group sorted by title, capped at 3 links.
   Drafts never reach these helpers — callers filter them out, matching
   the [slug] routes. Field notes carry no county field, so their county
   is read from the location string ("<place>, <county>") when present.
   Videos carry no county either, so a video can only match its town. */

export interface RelatedLink {
  href: string;
  title: string;
  kicker: string;
}

type Town = CollectionEntry<"towns">;
type Place = CollectionEntry<"places">;
type FieldNote = CollectionEntry<"field-notes">;
type Video = CollectionEntry<"videos">;

const MAX_LINKS = 3;

const norm = (s: string) => s.trim().toLowerCase();

const byTitle = <T extends { data: { title: string } }>(a: T, b: T) =>
  a.data.title.localeCompare(b.data.title);

/** True when a field note's location names a gazetteer place:
    the location is the place name, optionally followed by ", <county>". */
export function locationNamesPlace(location: string, place: string): boolean {
  const loc = norm(location);
  const p = norm(place);
  return loc === p || loc.startsWith(`${p},`);
}

/** The county named at the end of a field note's location, if any. */
export function countyFromLocation(location: string): string | undefined {
  const parts = location.split(",");
  if (parts.length < 2) return undefined;
  const last = parts[parts.length - 1].trim();
  return last.length > 0 ? last : undefined;
}

const sameCounty = (a: string, b: string) => norm(a) === norm(b);

export function relatedForVideo(video: Video, towns: Town[]): RelatedLink[] {
  const townName = video.data.town;
  if (!townName) return [];
  return towns
    .filter(t => norm(t.data.town) === norm(townName))
    .sort(byTitle)
    .slice(0, MAX_LINKS)
    .map(t => ({
      href: `/towns/${t.id}/`,
      title: t.data.title,
      kicker: `From the town archive — ${t.data.town}, ${t.data.county}`,
    }));
}

export function relatedForFieldNote(
  note: FieldNote,
  places: Place[],
  towns: Town[]
): RelatedLink[] {
  const named = places
    .filter(p => locationNamesPlace(note.data.location, p.data.place))
    .sort(byTitle);
  const links: RelatedLink[] = named.map(p => ({
    href: `/places/${p.id}/`,
    title: p.data.title,
    kicker: `Place — ${p.data.place}, ${p.data.county}`,
  }));

  const county = countyFromLocation(note.data.location);
  if (county) {
    const countyPlaces = places
      .filter(p => !named.includes(p) && sameCounty(p.data.county, county))
      .sort(byTitle);
    for (const p of countyPlaces) {
      links.push({
        href: `/places/${p.id}/`,
        title: p.data.title,
        kicker: `Place — also in ${p.data.county}`,
      });
    }
    const countyTowns = towns
      .filter(t => sameCounty(t.data.county, county))
      .sort(byTitle);
    for (const t of countyTowns) {
      links.push({
        href: `/towns/${t.id}/`,
        title: t.data.title,
        kicker: `From the town archive — ${t.data.town}, ${t.data.county}`,
      });
    }
  }
  return links.slice(0, MAX_LINKS);
}

export function relatedForPlace(
  place: Place,
  notes: FieldNote[]
): RelatedLink[] {
  const named = notes
    .filter(n => locationNamesPlace(n.data.location, place.data.place))
    .sort(byTitle);
  const links: RelatedLink[] = named.map(n => ({
    href: `/field-notes/${n.id}/`,
    title: n.data.title,
    kicker: `Field note — ${n.data.location}`,
  }));

  const countyNotes = notes
    .filter(n => {
      if (named.includes(n)) return false;
      const county = countyFromLocation(n.data.location);
      return county !== undefined && sameCounty(county, place.data.county);
    })
    .sort(byTitle);
  for (const n of countyNotes) {
    links.push({
      href: `/field-notes/${n.id}/`,
      title: n.data.title,
      kicker: `Field note — also in ${place.data.county}`,
    });
  }
  return links.slice(0, MAX_LINKS);
}

export function relatedForTown(
  town: Town,
  videos: Video[],
  places: Place[],
  notes: FieldNote[]
): RelatedLink[] {
  const links: RelatedLink[] = [];

  const films = videos
    .filter(v => {
      const filmedIn = v.data.town;
      return filmedIn !== undefined && norm(filmedIn) === norm(town.data.town);
    })
    .sort(byTitle);
  for (const v of films) {
    links.push({
      href: `/videos/${v.id}/`,
      title: v.data.title,
      kicker: `Film — filmed in ${town.data.town}`,
    });
  }

  const countyPlaces = places
    .filter(p => sameCounty(p.data.county, town.data.county))
    .sort(byTitle);
  for (const p of countyPlaces) {
    links.push({
      href: `/places/${p.id}/`,
      title: p.data.title,
      kicker: `Place — ${p.data.place}, ${p.data.county}`,
    });
  }

  const countyNotes = notes
    .filter(n => {
      const county = countyFromLocation(n.data.location);
      return county !== undefined && sameCounty(county, town.data.county);
    })
    .sort(byTitle);
  for (const n of countyNotes) {
    links.push({
      href: `/field-notes/${n.id}/`,
      title: n.data.title,
      kicker: `Field note — ${n.data.location}`,
    });
  }

  return links.slice(0, MAX_LINKS);
}
