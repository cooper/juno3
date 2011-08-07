# this is not a POE module

This is (or will be) a fully-featured IRCd. Why is that so surprising? People keep saying, "omg there is a POE module for ircd y r u making 1,"
but that fails and is very simple whereas this is completely customizable and packed with features. It's like asking one of the hundreds of 
people who have developed IRCds in C, "why are you writing an IRCd when there already is one?" I would guess that they were taking something and
making it better and better. I have also been told that "I don't like it" isn't a good enough reason not to use something, and that I must explain
why I don't like things. I guess I just never knew that I'm not allowed to create my own things if someone else has already created something
similar. besides, I don't want to set up an IRCd for any particular reason. I want to make one, so that is what I'm doing. (and have been for over a year)

## another good laugh

parts of juno are written in JavaScript.

## also

this is temporary. until this version of the IRCd is somewhat usable, this README probably won't help much. Basically this is an even more
customizable version of juno 2. It also has a server linking protocol now.

## efficiency and stability

juno3 is a work in process. I do my best to ensure that the IRCd never randomly exits or anything of that nature; instead it should log errors
and attempt to continue. juno has become surprisingly efficient. The power and speed of perl allows juno to do many operations in a small amount
of time. I specifically take time to ensure that there are no memory leaks. juno3 has a problem where references refer to themselves, but I have
solved the issue and put more time into making juno more memory-friendly. juno should track and log the location of data when a user quits, a
connection is closed, a server leaves the network, etc.

## dependencies

This IRCd is designed to be used out-of-the-box, using all core modules up until August 7, 2011 when IO::Socket::IP became the only Perl module
not in Perl's core module list that juno relies on. Up until this change, you were able to specify a drop-in replacement for IO::Socket::INET
or use IO::Socket::INET itself in the configuration for a socket class, but in order to clear confusion IO::Socket::IP is now required.
IO::Socket::IP provides an interface to both IPv4 and an invisible interface to IPv6 (when available). IO::Socket::IP is included with juno that
way the "use out-of-the-box" idea stays intact. IO::Socket::IP is the work of Paul Evans, see dep/IO/Socket/IP.pm for
licensing information or view the module on [[CPAN|http://search.cpan.org/perldoc?IO::Socket::IP]].  
  
**tl;dr**: it works out of the box

## installation

* configure the ircd and save it as etc/ircd.conf
* `./juno start`
* done

## author and history

Mitchell Cooper, <mitchell@notroll.net>
  
juno-ircd started as a fork of pIRCd. Even though pIRCd might not be some of the best work *anymore*, it was a great example to learn from.
I called it pIRCd2 for a while up until Elijah Perrault (iElijah101 on GitHub) decided on a name for me. I don't know what it means, but
there's a movie that uses the same name so I feel that it must be cool enough to use. I added some various features to pIRCd. It was probably
the buggiest IRCd in existence, and I'm pretty sure that the copy on GitHub is broken and doesn't even run anymore.  
`[04:15pm] -Global- [Network Notice] Alice (nenolod) - We will be upgrading to "juno-ircd" in 5 seconds.`  
Anyway, I stopped developing juno-ircd because of some unknown reason that I have forgotten. I was probably getting tired of people laughing
at me and my IRCd written in Perl. Many moments later I began to rewrite juno from scratch. Looking back at old commit history, I was not
prepared to rewrite juno again. By the time I learned more and more about Perl I realized that much of juno was full of crap code even after
I completely rewrote it. juno2 was nearly fully-featured. It had an extensive module API and quite a few built-in features that were cool.
I don't know why I'm talking in the past tense because it still exists on my github on the "juno" repository. I cleaned up juno so much.
I was doing commits every 5 minutes changing things to be prettier and more efficient. After I finally got the code mostly cleaned up I
realized that juno will never have a linking protocol. It was designed on the idea of a single-server network, unfortunately. and thus
juno3 was born. juno3 is a another complete rewrite. It is a major improvement. juno3 features something that no other version of juno did:
a linking protocol. But there's more to juno3 than just a linking protocol. 

## customization

juno3 could be looked at as more of an ircd "library" instead
of a hard-coded IRCd. juno3 heavily revolves around the idea of compatibility and interchangeableness. It is very customizable. Soon it
will have a very impressive API, making it possible for API modules to do almost anything. When you start juno, your terminal will be
flooded with registration logs. 70% or more of the code in juno is probably accessed through code references stored in locations that
have names. For example, someone might create an API module that allows anyone to invite users with a certain channel mode specified.
To do this, their module would delete the check named "internal_must_have_op" for the INVITE command and register a new block that
returns a true value if the channel mode that allows all users to invite is enabled or returns true if it is not but the user has op.
juno will be heavily documented, and there will be guides to creating API modules to do exactly what you want.
