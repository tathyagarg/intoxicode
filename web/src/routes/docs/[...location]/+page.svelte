<script lang="ts">
  import { marked } from "marked";
  import { getHeadingList, gfmHeadingId } from "marked-gfm-heading-id";

  let { data } = $props();

  $effect(() => {
    if (data.title) document.title = data.title;

    document.addEventListener("keydown", (e) => {
      if (e.key === "ArrowLeft") {
        e.preventDefault();

        if (data.prev?.location) {
          window.location.href = `/docs/${data.prev.location}`;
        }
      } else if (e.key === "ArrowRight") {
        e.preventDefault();

        if (data.next?.location) {
          window.location.href = `/docs/${data.next.location}`;
        }
      }

      if (window.Prism) window.Prism.highlightAll();
    });
  });

  marked.use(gfmHeadingId({ prefix: "heading-" }));
</script>

<svelte:head>
  <link rel="stylesheet" href="/prism/macchiato.css" />
  <script src="/prism/prism.js" defer></script>
</svelte:head>

<div class="flex flex-row min-h-screen bg-mantle">
  <div class="flex flex-col gap-4 flex-1">
    <div class="p-4 prose prose-awesome font-sans min-w-2/3 flex-1">
      {@html marked(data.content)}
    </div>
    <div
      class="w-full h-30 grid grid-cols-2 grid-rows-1 p-2 gap-2 *:rounded-lg *:text-center *:leading-26"
    >
      {#if data.prev?.name}
        <a
          href={`/docs/${data.prev?.location}`}
          class="underline text-base font-bold"
        >
          <div class="bg-green rounded-lg">
            &#8592; Previous: {data.prev?.name}
          </div>
        </a>
      {:else}
        <div class="bg-surface2">No previous page</div>
      {/if}
      {#if data.next?.name}
        <a
          href={`/docs/${data.next?.location}`}
          class="underline text-base font-bold"
        >
          <div class="bg-green rounded-lg">
            Next: {data.next?.name}
            &#8594;
          </div>
        </a>
      {:else}
        <div class="bg-surface2">No next page</div>
      {/if}
    </div>
  </div>
  <div class="bg-base w-1/3 min-h-full">
    <div class="sticky top-0">
      {#each getHeadingList() as heading}
        <div class="p-2">
          <a
            href={`#${heading.id}`}
            class="text-lg font-semibold"
            style={`margin-left: ${heading.level * 20}px;`}
          >
            {@html heading.text}
          </a>
        </div>
      {/each}
    </div>
  </div>
</div>
