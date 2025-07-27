<script lang="ts">
  import { Play, Download, Upload } from "lucide-svelte";
  import { basicSetup, EditorView } from "codemirror";
  import { keymap } from "@codemirror/view";
  import { indentWithTab } from "@codemirror/commands";
  import { EditorState, Compartment } from "@codemirror/state";

  import { browser } from "$app/environment";
  import { onMount } from "svelte";

  let tabsize = new Compartment();

  let state = EditorState.create({
    doc: `scream("Hello, World!").`,
    extensions: [
      basicSetup,
      tabsize.of(EditorState.tabSize.of(4)),
      keymap.of([indentWithTab]),
      EditorView.theme(
        {
          "&": {
            color: "var(--color-text)",
            backgroundColor: "var(--color-crust)",
            fontSize: "24px",
            height: "100%",
          },

          "&.cm-focused": {
            outline: "none",
          },

          ".cm-activeLine": {
            backgroundColor: "rgba(from var(--color-surface0) r g b / 0.50)",
          },

          "&.cm-focused > .cm-scroller > .cm-selectionLayer .cm-selectionBackground, .cm-selectionBackground, .cm-content ::selection":
            { backgroundColor: "rgba(from var(--color-green) r g b / 0.25)" },

          ".cm-activeLineGutter": {
            backgroundColor: "var(--color-base)",
          },

          ".cm-gutters": {
            color: "var(--color-text)",
            backgroundColor: "var(--color-crust)",
            borderRight: "1px solid var(--color-surface0)",
          },
          ".cm-selectionBackground": {
            backgroundColor: "var(--color-surface1)",
          },

          ".cm-editor ::selection": {
            backgroundColor: "var(--color-surface1)",
          },
        },
        { dark: true },
      ),
    ],
  });

  let view: EditorView;

  onMount(() => {
    if (browser) {
      view = new EditorView({
        state,
        parent: document.querySelector("#code") || document.body,
      });
    }
  });

  let stdout = "stdout";
  let stderr = "stderr";
  let runClicked = false;

  async function run() {
    try {
      runClicked = true;

      const res = await fetch("/api/eval", {
        method: "POST",
        headers: {
          "Content-Type": "text/plain",
        },
        body: view.state.doc.toString(),
      });

      let response = await res.json();
      stdout = response.stdout || "No output";
      stderr = response.stderr || "No errors";

      setTimeout(() => {
        runClicked = false;
      }, 1000);
    } catch (e) {}
  }

  function download() {
    const blob = new Blob([view.state.doc.toString()], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "main.??";
    a.click();
  }

  function upload() {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = ".??";

    input.onchange = async () => {
      const file = input.files[0];
      const text = await file.text();
      view.dispatch({
        changes: { from: 0, to: view.state.doc.length, insert: text },
      });
    };

    input.click();
  }
</script>

<svelte:head>
  <title>IDE</title>
</svelte:head>

<div class="flex flex-col w-full h-screen">
  <div class="flex p-4 w-full h-full gap-4 flex-row">
    <div
      class="bg-mantle w-full p-6 pt-4 h-full rounded-md flex flex-col flex-1 md:w-2/3"
    >
      <div class="flex">
        <h1 class="text-3xl font-bold">Input</h1>
        <div class="ml-auto flex">
          <button
            class={`${runClicked ? "text-green" : ""} mr-5`}
            on:click={run}
          >
            <Play size={28} class="my-auto" />
          </button>

          <button class="mr-5" on:click={upload}>
            <Download size={28} class="my-auto" />
          </button>

          <button on:click={download}>
            <Upload size={28} class="my-auto" />
          </button>
        </div>
      </div>
      <div id="code" class="mt-4 h-full rounded-md overflow-scroll"></div>
    </div>

    <div class="flex flex-col gap-4 w-1/3">
      <div
        class="bg-mantle w-full p-6 pt-4 h-full max-h-1/2 rounded-md flex flex-col flex-1"
      >
        <h1 class="text-3xl font-bold">
          <code class="text-green">stdout</code>
        </h1>
        <pre
          class="p-4 mt-4 text-xl break-words whitespace-pre-wrap bg-crust h-full max-h-full overflow-y-scroll rounded-md">{stdout}</pre>
      </div>
      <div
        class="bg-mantle w-full p-6 pt-4 h-full max-h-1/2 rounded-md flex flex-col flex-1"
      >
        <h1 class="text-3xl font-bold"><code class="text-red">stderr</code></h1>
        <pre
          class="p-4 mt-4 text-xl break-words whitespace-pre-wrap bg-crust h-full rounded-md">{stderr}</pre>
      </div>
    </div>
  </div>
</div>
