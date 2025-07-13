<script lang="ts">
  import "../app.css";

  let { children } = $props();
</script>

<svelte:head>
  <meta property="og:title" content="Intoxicode - An esolang" />
  <meta
    property="og:description"
    content="Run code like a drunk person would write it"
  />
  <meta
    name="description"
    content="Run code like a drunk person would write it"
  />
  <meta property="og:site_name" content="arson.dev" />
  <meta property="og:url" content="https://intoxicode.arson.dev" />
  <meta property="og:image" content="/assets/preview.png" />
</svelte:head>

<div
  class="bg-crust text-subtext0 p-4 flex items-center gap-8 *:hover:text-text"
>
  <a href="/">Home</a>
  <a href="/docs">Docs</a>
  <button onclick={() => (window.location.href = "/ide")}>IDE</button>
</div>
<div
  class="min-h-screen min-w-screen max-w-screen bg-base text-text flex flex-col"
>
  <div class="flex-1">
    {@render children()}
  </div>
  <div
    class="text-sm text-subtext0 p-4 bg-crust flex justify-center gap-8 items-center"
  >
    <div class="flex gap-2 items-center">
      <span>Powered by</span><img
        src="/svelte.svg"
        alt="SvelteKit"
        class="h-6"
      />
    </div>
    <div>
      Inspired by <a href="https://github.com/cyteon/modu" class="text-blue"
        >Modu</a
      >
    </div>
  </div>
</div>
