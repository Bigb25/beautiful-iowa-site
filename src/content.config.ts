import { defineCollection } from "astro:content";
import { z } from "astro/zod";
import { glob } from "astro/loaders";
import config from "@/config";

export const BLOG_PATH = "src/content/posts";

const posts = defineCollection({
  loader: glob({ pattern: "**/[^_]*.{md,mdx}", base: `./${BLOG_PATH}` }),
  schema: ({ image }) =>
    z.object({
      author: z.string().default(config.site.author),
      pubDatetime: z.date(),
      modDatetime: z.date().optional().nullable(),
      title: z.string(),
      featured: z.boolean().optional(),
      draft: z.boolean().optional(),
      tags: z.array(z.string()).default(["others"]),
      ogImage: image().or(z.string()).optional(),
      description: z.string(),
      canonicalURL: z.string().optional(),
      hideEditPost: z.boolean().optional(),
      timezone: z.string().optional(),
    }),
});

const pages = defineCollection({
  loader: glob({ pattern: "**/[^_]*.{md,mdx}", base: "./src/content/pages" }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    ogImage: z.string().optional(),
    canonicalURL: z.string().optional(),
  }),
});

/* Beautiful Iowa collections (see ~/workspace/beautiful-iowa-site/SITE_PLAN.md).
   towns       — the Iowa, On This Day archive: one entry per town week.
   field-notes — the blog of places we go.
   videos      — a permanent page for every Beautiful Iowa film. */

const towns = defineCollection({
  loader: glob({ pattern: "**/[^_]*.{md,mdx}", base: "./src/content/towns" }),
  schema: z.object({
    title: z.string(),
    town: z.string(),
    county: z.string(),
    pubDatetime: z.date(),
    description: z.string(),
    heroImage: z.string().optional(),
    heroCaption: z.string().optional(),
    sourceNote: z.string().optional(),
    featured: z.boolean().optional(),
    draft: z.boolean().optional(),
  }),
});

const fieldNotes = defineCollection({
  loader: glob({
    pattern: "**/[^_]*.{md,mdx}",
    base: "./src/content/field-notes",
  }),
  schema: z.object({
    title: z.string(),
    location: z.string(),
    pubDatetime: z.date(),
    description: z.string(),
    heroImage: z.string().optional(),
    heroCaption: z.string().optional(),
    draft: z.boolean().optional(),
  }),
});

const videos = defineCollection({
  loader: glob({ pattern: "**/[^_]*.{md,mdx}", base: "./src/content/videos" }),
  schema: z.object({
    title: z.string(),
    pubDatetime: z.date(),
    description: z.string(),
    youtubeId: z.string().optional(),
    duration: z.string().optional(),
    town: z.string().optional(),
    heroImage: z.string().optional(),
    heroCaption: z.string().optional(),
    draft: z.boolean().optional(),
  }),
});

export const collections = {
  posts,
  pages,
  towns,
  "field-notes": fieldNotes,
  videos,
};
