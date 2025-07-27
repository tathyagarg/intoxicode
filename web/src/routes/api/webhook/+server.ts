import { writeFile, mkdir } from 'fs/promises'
import { join } from 'path'
import { json } from "@sveltejs/kit";
import { spawn } from 'child_process';
import { Webhooks } from "@octokit/webhooks"
import { GITHUB_SECRET } from "$env/static/private"
import { PUBLIC_RUNNER_OS } from "$env/static/public";
import { make_target } from "$lib";

const reqd_target = make_target(PUBLIC_RUNNER_OS)

const webhooks = new Webhooks({
  secret: GITHUB_SECRET,
})

export async function POST({ request }: { request: Request }) {
  const headers = request.headers;
  const body = await request.text();

  const signature = headers.get('x-hub-signature-256') ?? ":("

  if (!body || !(await webhooks.verify(body, signature))) {
    return json({
      ok: false,
      message: "Could not verify payload authenticity",
      payload: body
    }, { status: 401 })
  }

  queueMicrotask(async () => await processData(JSON.parse(body)));

  return json({}, {
    status: 200
  })
}

async function processData(data: any) {
  if (data.action !== 'completed') {
    return
  }

  spawn('git', ['pull'])

  const releases = await fetch('https://api.github.com/repos/tathyagarg/intoxicode/releases/latest')
  const release_data = await releases.json()

  for (const asset of release_data.assets) {
    if (asset.name != reqd_target) {
      continue
    }

    const release = await fetch(asset.browser_download_url)
    const fileBuf = await release.arrayBuffer();
    const uint8Array = new Uint8Array(fileBuf);

    const downloadDir = 'static/assets/releases'
    const fp = join(downloadDir, reqd_target)

    await mkdir(downloadDir, { recursive: true })
    await writeFile(fp, uint8Array);

    spawn('chmod', ['+x', fp])
  }

  spawn('npm', ['install'])
  spawn('npm', ['run', 'build'])
}
