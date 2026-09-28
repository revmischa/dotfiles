---
name: proxy
description: Shadow-run the mischa-proxy agent on the question you just asked me. Show its verdict, then let me rule.
disable-model-invocation: true
---

# Proxy

I am running the proxy in shadow mode. Do not act on its verdict until I rule.

1. **Restate the question you just asked me**, verbatim, as the proxy's input. Include the
   context a stranger to this session needs: what I asked you to do, what you have done,
   what you are stuck on or deciding, and every option you offered me with your
   recommendation. Do not soften or reshape the question; the proxy must see what I saw.
2. **Dispatch the `mischa-proxy` agent** with that input and wait for it. The proxy always
   commits to an answer. If its output contains no answer, or says the question must go
   to me without predicting what I would say, that is a defect: show me the output as-is
   and say so.
3. **Show me its verdict verbatim** under a heading that is exactly:

   ```
   ## Proxy verdict — <TYPE>
   ```

   followed by the proxy's full output, unedited, including its `Mischa's call:` line.
   Then stop and wait.
4. **Record my ruling.** My next message is the ruling. Echo it under exactly one of:

   ```
   ## Proxy ruling — AGREE
   ## Proxy ruling — DISAGREE
   ## Proxy ruling — PARTIAL
   ```

   AGREE: proceed on the proxy's answer. DISAGREE: my message is the answer; proceed on
   mine. PARTIAL: I accepted the direction but changed the substance; state in one line
   what changed, then proceed on my version. Directly under the heading add one line
   `Mischa's call: right|wrong`: whether the proxy was right about needing to ask me at
   all. If my message does not make the ruling obvious, ask which of the three it is,
   that one question only.

The headings are markers for a later retro measuring how often the proxy and I agree.
Never omit or paraphrase them, and never emit them when this command was not invoked.
