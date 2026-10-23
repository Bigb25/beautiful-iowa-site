import { defineAstroPaperConfig } from "./src/types/config";

export default defineAstroPaperConfig({
  site: {
    url: "https://beautifuliowa.org/",
    title: "Beautiful Iowa",
    description:
      "Beautiful Iowa is a showcase of the state we live in: river bluffs and state parks, small-town main streets and back roads. It is the permanent home of the Beautiful Iowa films, the Iowa, On This Day town archive, and field notes from the places we go.",
    author: "Beautiful Iowa",
    profile: "https://beautifuliowa.org",
    ogImage: "default-og.jpg",
    lang: "en",
    timezone: "America/Chicago",
    dir: "ltr",
  },
  posts: {
    perPage: 4,
    perIndex: 4,
    scheduledPostMargin: 15 * 60 * 1000,
  },
  features: {
    lightAndDarkMode: true,
    dynamicOgImage: true,
    showArchives: true,
    showBackButton: true,
    editPost: {
      enabled: false,
    },
    search: "pagefind",
  },
  socials: [
    { name: "youtube", url: "https://www.youtube.com/@BeautifulIowa" },
    { name: "mail", url: "mailto:b.dealwatch@gmail.com" },
  ],
  shareLinks: [
    { name: "facebook", url: "https://www.facebook.com/sharer.php?u=" },
    { name: "pinterest", url: "https://pinterest.com/pin/create/button/?url=" },
    { name: "mail", url: "mailto:?subject=See%20this%20post&body=" },
  ],
});
