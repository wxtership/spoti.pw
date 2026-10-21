// Spoof Premium is removed from this build. The account's real product state is never rewritten:
// both entry points answer nil, which callers already treat as "leave the response as it is".
#import "AdBlock.h"

NSData *SGPatchCustomize(NSData *body) { return nil; }
NSData *SGPatchBootstrap(NSData *body) { return nil; }
