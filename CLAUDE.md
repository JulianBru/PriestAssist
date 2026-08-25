# Working on PriestAssist

## Ask before deciding. Every time.

Do not build anything that was not explicitly asked for. Not a command, not an
option, not a helper "while we are in there". If it seems like a good idea,
**propose it and wait for an answer.**

This includes the cases where it feels like permission was already given:

- **A question that got a different answer is not an answer.** If two things are
  asked in one message and only one is addressed, the other is still open. Ask
  again, do not assume the silence was a yes.
- **"You are right" is agreement with the reasoning, not approval of a plan.**
- **Being told to continue means continue with what was agreed**, not with
  whatever seemed like the obvious next step.
- **Finding a problem is not permission to fix it a particular way.** Report the
  finding, say what the options are, and let Julian pick.

When something is genuinely blocking, say what is blocking and ask. An hour of
waiting costs less than code that has to be taken out again.

## Say what changed, including the parts nobody asked about

Behaviour that changes as a side effect of something else is the thing most
worth mentioning, not the thing to leave out because it was minor. Two examples
from this project, both caught late:

- folding the mute setting into a shared send path silently disabled the target
  announcement, which has its own switch
- splitting a function so a timer could call it made the second half public, and
  the second half had none of the checks

## Verify against the old code, not only the new

A test that passes on the broken version proves nothing. Stash the change, run
the harness, and confirm the relevant checks actually fail. Say which ones
discriminate and which are only regression guards -- do not present the whole
suite as proof of the fix.

## Read the code before claiming what it does

Several claims in this project turned out to be invented from a name:

- `RequestGroupSpecialization` was described as usable; it is an empty deprecated
  stub, and the comment inside says why
- the "voidform" macro variant was described as self-infusing; both variants
  build the identical target line
- `AnnounceMacroTarget` was described as respecting mute; it never did

Thirty seconds of grep beats a plausible sentence.

## Secret values and chat

Anything arriving from a `CHAT_MSG_*` event -- text *and* sender -- can be a
secret value on a communication-restricted map, which includes dungeons and
raids. Tainted code may hold and pass such a value but never read it: `find`,
`match` and indexing all throw immediately. Guard with `ns.IsSecretValue` at the
event handler *and* inside any public function that receives it.

The same applies to `UnitName`, `UnitClass` and `UnitClassBase`.

## Conventions

- Comments explain *why*, in the same voice as the surrounding file. No comment
  that only restates the line below it.
- LF line endings. `sed -i 's/\r$//'` before every check; CRLF keeps creeping in.
- Changelog entries follow the 1.7 style: plain, short, one fact per bullet.
  Not the 1.6 style with bold lead-ins and paragraphs.
- Julian commits. Offer a commit message, do not run `git commit`.
- The test harnesses live in the outputs folder and are throwaway. They load the
  real files in `.toc` order against stubbed WoW APIs.
