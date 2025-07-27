import { json } from "@sveltejs/kit";
import { Webhooks } from "@octokit/webhooks"
import { GITHUB_SECRET } from "$env/static/private"

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
      message: "Could not verify payload authenticity"
    }, { status: 401 })
  }

  console.log(headers);
  console.log(body)

  return json({}, {
    status: 200
  })
}
