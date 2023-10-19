# Rotkeappchen - Rotating Captcha

Rotkeappchen is a design proposal for a [captcha](https://en.wikipedia.org/wiki/CAPTCHA)
system that does not require keeping track of challenges and can run completely
independent of a database.

_This library does not include methods for further processing and generating visual
captcha challenges. Instead I suggest you take a look at this [repository](https://github.com/DISTREAT/captcha-generator)._

_Note: Build using zig version 0.11.0._

## A new approach for keeping track of CAPTCHA challenges

Inspired by [TOTP](https://en.wikipedia.org/wiki/Time-based_one-time_password),
I propose a draft for an algorithm that could be used for generating and verifying
the validity of captcha challenges.

On one hand, the advantage of using this algorithm is that it uses solely cryptographic
algorithms, thus guaranteeing uptime, stability, and efficiency. On the other hand, its
its security depends on the request-identifying salt and addition security-measures.

## Algorithm

The goal of the algorithm is to generate a digest that is to be further processed
as the captcha challenge. This code should persist a variable time frame, so that
calculating the algorithm again results in the same code.

```
H(concatenate(S, P, floor(T / Tx) + O))
```

The following parameters are used:
| Parameter 	| Description 	|
|---	|---	|
| H 	| Hashing algorithm 	|
| S 	| Request-identifying salt, identifying the request made 	|
| P 	| Shared secret, protecting against calculability by a third-party 	|
| T 	| Time stamp (ex. Unix Time) 	|
| Tx 	| Time frame in seconds, after which a new resulting digest will be generated 	|
| O 	| Subtract or add to this factor to calculate ahead or previous codes (defaults to 0) 	|

The returning hash digest is to be further processed (ex. truncated and encoded) for
generating a user-friendly challenge.

To overcome the issue of synchronization, we suggest (similar to [RFC 4226](https://datatracker.ietf.org/doc/html/rfc4226))
calculating a window of `S`, in this case as a look-back buffer though (ex. calculating a digest for `O=-1` and `O=0`).
The reason is that if the server calculates a challenge and sends it over to the client, but the counter increments directly afterwards,
then the server is still capable of verifying the validity of the challenge. Note that this is also the reason why
the time frame `Tx` does not equal the expiration time of a generated challenge solution.

### Security requirements and concerns

#### Hashing Algorithm

Unlike [HOTP](https://en.wikipedia.org/wiki/HMAC-based_one-time_password), I propose using a
hashing algorithm that is resistant to [Length Extension Attacks](https://en.wikipedia.org/wiki/Length_extension_attack),
such as of SHA-3 or truncated versions of SHA-2. This issue should not exist if the resulting digest
is truncated manually. In addition, and due to the nature of the application, collision resistance
is not a primary goal. Nonetheless, more collisions will result in a better guesswork of a potential
attacker. Choosing a hashing algorithm with good [Avalanche Effect](https://en.wikipedia.org/wiki/Avalanche_effect)
should reduce the probability of collisions when truncating.

One absolutely essential attribute is to choose a hashing algorithm with good preimage resistance to prevent
an attacker from finding the secret, since the other input parameters are retrievable.

#### Request-identifying salt

This parameter is crucial to the security and easy to mess-up. Because the request-identifying salt is likely stored client-side
and passed with requests made, it should be designed per-request and per-request only. This implies that instead of using a random
salt stored client-side (as a session token), use a salt that changes with each request (ex. registration of users -> unique username requested).

##### Example

To prevent users from mass-registering unique usernames, every captcha challenge should be generated with the username as a salt, because
that way every username generates its own challenge. Contrary, if a session token was used as a request-identifying salt, an attacker could easily use
a solved challenge for registering multiple usernames.

#### Shared secret

A good requirement is having a lengthy secret to mitigate the risk of [Brute Force](https://en.wikipedia.org/wiki/Brute-force_search),
I suppose a length above 32 bytes should be more than sufficient. This secret is to be stored with highest
security and should never be disclosed.

In case the secret is disclosed nonetheless, make sure to change it immediately.

#### Time frame

The time frame in which a digest persists should be long enough that it does not interfere with the usability, but also
relatively short to prevent the request-identifying salt from being used for a [DDoS/DoS Attack](https://en.wikipedia.org/wiki/Denial-of-service_attack).

#### Window Size

The window size used for mitigating desynchronization should be small, so to reduce the amount of calculation made and to prevent
a [DDoS/DoS Attack](https://en.wikipedia.org/wiki/Denial-of-service_attack).

#### Challenge Generating

Generating random gibberish is one thing, but the next step is serving it in a user-friendly manner.
The returned digest could theoretically be used for any captcha challenge design.
Therefore, the challenge design (ex. enter numbers seen in picture, slide to match pieces) determines whether
it is good at recognizing bots or not. And because technologies get better, we will need to find alternative solutions eventually.

### Example integration

Suppose a simple website where users can submit a newsletter subscription via their e-mail address.

Before a user submits their e-mail address, a request is sent to the server along with the e-mail address provided to retrieve a challenge:

The algorithm is now calculated using the following parameters:
| Parameter 	| Value 	|
|---	|---	|
| H 	| Sha-224 	|
| S 	| E-Mail address 	|
| P 	| THISISMYSECRETSECRETUSEDFORROTKEAPPCHEN 	|
| T 	| 1697476412 	|
| Tx 	| 60 	|
| O 	| 0 	|

The module will then calculate the digest and truncate to the first 6 bytes, adding noise and exporting it as the response.

Now that the user has solved the challenge they will submit their newsletter subscription request along with the solution.
The server now calculates the same algorithm along, trying `O=-1` if the code does not match the solution.
In case the solution does not match then the request will be denied, otherwise the server further processes the request.

The captcha was successfully solved, and the user is not a robot.

