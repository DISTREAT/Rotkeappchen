# Rotkeappchen - Rotating Captcha

Rotkeappchen is a design proposal for a [captcha](https://en.wikipedia.org/wiki/CAPTCHA)
system that does not require keeping track of challenges and can run completely
independent of a database.

This library does not include methods for further processing and generating visual
captcha challenges. Instead, I suggest you take a look at my other repositories:
- [CAPTCHA-System](https://github.com/DISTREAT/captcha-system):
Fully-fledged implementation of Rotkeappchen including CAPTCHA challenge generation.
- [CAPTCHA-Generator](https://github.com/DISTREAT/captcha-generator):
Bun-compatible typescript library for generating CAPTCHA challenges using ImageMagick.

_Note: Build using Zig version 0.11.0._

## A new approach for keeping track of CAPTCHA challenges

Inspired by [TOTP](https://en.wikipedia.org/wiki/Time-based_one-time_password),
I propose a draft for an algorithm that generates and verifies
the validity of captcha solutions.

A CAPTCHA system consists of two different parts: A system that comes up with a seed for
generating a CAPTCHA challenge and the creation of the challenge itself that is to be
presented to the end-user.

This proposal does not suggest a new CAPTCHA challenge type but rather proposes a way to
generate [seeds](https://en.wikipedia.org/wiki/Random_seed) that can be used to
[encode](https://en.wikipedia.org/wiki/Encoding) CAPTCHA challenges.

The proposed algorithm has the advantage of being able to regenerate the same seed which
allows for an easy validation of the user's provided solution.

On one hand, the advantage of following this idea is that it uses solely cryptographic
algorithms, thus guaranteeing uptime, stability, efficiency, and error resistance.
On the other hand, its security depends on the request-identifying salt (explanation following)
and additional security measures.

## Algorithm

The goal of the algorithm is to generate a digest that is to be further processed
as the captcha challenge. This resulting digest should persist a variable time frame so that
calculating the algorithm again results in the same digest.

```
h(concatenate(s, p, floor(t / tx) + o))
```

The following parameters are used:
| Parameter 	| Description 	|
|---	|---	|
| h 	| Hashing algorithm 	|
| s 	| Request-identifying salt, identifying the request made 	|
| p 	| Shared secret, protecting against calculability by a third party 	|
| t 	| Time stamp (ex. Unix Time) 	|
| tx 	| Time frame in seconds, after which a new resulting digest will be generated 	|
| o 	| Subtract or add to this factor to calculate ahead or recalculate previous digests (defaults to 0) 	|

The returned hash digest is to be further processed (ex. truncated and encoded) to generate a user-friendly challenge.
This could be as simple as taking the first 2 bytes of the digest, encoding it to hexadecimal, and storing it within
an image for the user to copy. The validation works by calculating the algorithm again and comparing the provided
hexadecimal values to the first two bytes of the digest.

To overcome the issue of synchronization, we suggest (similar to [RFC 4226](https://datatracker.ietf.org/doc/html/rfc4226))
calculating a window of `s`, in this case as a look-back buffer though (ex. calculating a digest for `o=-1` and `o=0`).
The reason is that if the server calculates a challenge and sends it over to the client, but the counter increments directly afterward,
then the server is still capable of verifying the validity of the last challenge. Note that this is also the reason why
the time frame `tx` does not equal the expiration time of a generated digest.

### Security requirements and concerns

#### Hashing Algorithm

Unlike [HOTP](https://en.wikipedia.org/wiki/HMAC-based_one-time_password), I propose using a
hashing algorithm that is resistant to [Length Extension Attacks](https://en.wikipedia.org/wiki/Length_extension_attack),
such as SHA-3, Blake3, or truncated versions of SHA-2. This issue should not exist if the resulting digest
is truncated manually.


In addition, and due to the nature of the application, collision resistance
is not a primary goal. Nonetheless, more collisions will result in better guesswork of a potential
attacker. Choosing a hashing algorithm with good [Avalanche Effect](https://en.wikipedia.org/wiki/Avalanche_effect)
should reduce the probability of collisions when truncating.

One essential attribute is to choose a hashing algorithm with good preimage resistance to prevent
an attacker from finding the secret since the other input parameters are retrievable. Once again,
truncating will add redundancy which in return should in theory prevent finding the secret in the first place.

#### Request-identifying salt

This parameter is crucial to security and easy to mess up. Because the request-identifying
[salt](https://en.wikipedia.org/wiki/Salt_(cryptography)) is likely stored client-side
and passed with requests made, it should be designed per request and per request only.
This implies that instead of using a random salt stored client-side (as a session token),
use a salt that changes with each request (ex. registration of users -> unique username requested).

##### Example

To prevent users from mass-registering unique usernames, every captcha challenge should be generated
with the username as a salt, because that way every username generates a unique challenge.
Contrary, if a session token was used as a request-identifying salt, an attacker could easily use
a solved challenge for registering multiple usernames.

#### Shared secret

A good requirement is having a lengthy secret to mitigate the risk of [Brute Force](https://en.wikipedia.org/wiki/Brute-force_search),
I suppose a length above 32 bytes should be more than sufficient. This secret is to be stored with the highest
security and should never be disclosed.

In case the secret is disclosed nonetheless, make sure to change it immediately.

This secret is to be thought of as a [pepper](https://en.wikipedia.org/wiki/Pepper_(cryptography)) and is the backing force, preventing calculability by a third party.

#### Time frame

The time frame in which a digest persists should be long enough that it does not interfere with the usability, but also
relatively short to prevent the request-identifying salt from being used for a [DDoS/DoS Attack](https://en.wikipedia.org/wiki/Denial-of-service_attack).

#### Window Size

The window size used for mitigating desynchronization should be small, to reduce the amount of calculation made and prevent
a [DDoS/DoS Attack](https://en.wikipedia.org/wiki/Denial-of-service_attack).

#### Challenge Generating

Generating random data is one thing, but the next step is serving it in a user-friendly manner.
The returned digest could theoretically be used for any captcha challenge design.
Therefore, the challenge design (ex. "copy numbers seen in the picture", "slide to match pieces") determines whether
it is good at recognizing computers or not. And because technologies get better, we will need to find alternative solutions eventually.

Moreover, we will also require alternative CAPTCHA systems that do not require user interaction,
such as the [invisible CAPTCHA](https://developers.google.com/recaptcha/docs/invisible) by Alphabet.

### Example integration

Suppose a simple website where users can submit a newsletter subscription via their e-mail address.

Before a user submits their e-mail address, a request is sent to the server along with the e-mail
address provided to retrieve a CAPTCHA challenge.

The server now interprets the request and uses the proposed algorithm to generate a hash digest using
the user's e-mail address as a request-identifying salt. Right after, the digest is truncated to the
first 3 bytes, converted to hexadecimal, and converted into an OCR-proof image representation.

The user is now confronted with the server's response, including the CAPTCHA challenge.

Once the user solves the challenge, they will submit their newsletter subscription request along with the challenge solution.
The server now calculates the same algorithm for `o=0`, trying `o=-1` if the digest does not match the solution when
truncated and converted to hexadecimal.

In case the solution does not match then the request will be denied, otherwise, the server further processes the
request proofing the captcha as solved.

