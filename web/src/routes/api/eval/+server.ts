import { json } from '@sveltejs/kit';
import { spawn } from 'child_process';
import { PUBLIC_RUNNER_OS } from '$env/static/public';

const intoxicodePath = `static/assets/releases/intoxicode-${PUBLIC_RUNNER_OS}-x86_64`;

export async function POST({ request }: { request: any }) {
  const code = await request.text();

  const proc = spawn(intoxicodePath, ['-c', code]);
  let stdout = '';
  let stderr = '';

  proc.stdout.on('data', (data) => { stdout += data.toString(); });
  proc.stderr.on('data', (data) => { stderr += data.toString(); });

  await new Promise((resolve, reject) => { proc.on('close', resolve); });

  return json({
    stdout,
    stderr
  })
}
