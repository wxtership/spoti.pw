// Player redesign: nothing is kept under the player. Every card (about the artist, videos, SongDNA,
// events, explore, credits, merch, the lyrics card, anything Spotify adds later) reports no height, so
// the list closes up around it and the player is one screen; PlayerScroll.x closes off the gaps the
// list leaves between them, and the lyrics come to the player itself (PlayerLyrics.x) instead of
// waiting on a card below it.
//
// A block on everything rather than a list of what to drop: the server decides which cards a track
// gets, and a new kind should not turn up under a redesigned player. The collapse is the one
// Native/Player/PlayerDeclutter.x has shipped.
//
// Tree (trees/clean/player/01.txt:385, lyrics/01.txt:996-999): every card is an Element_List.CollectionViewCell
// whose first subview is an ElementContentView naming NowPlaying_ScrollAPI, then an ElementView, then
// the card's own root: CreatorBiographyCardLayout, song-dna-npv-card, Lyrics_CardElementImpl.CardView
// id=lyrics-card-view and so on (all ten player snapshots). The cells of lists inside a card
// (WatchFeed's) name WatchFeed_ComponentAPI instead, so they are left to their card.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Player.h"

// Whether the cell's content is the player's card list, remembered per content class.
static BOOL isPlayerCard(UIView *content) {
    static NSMutableSet<Class> *yes, *no;
    if (!yes) {
        yes = [NSMutableSet set];
        no = [NSMutableSet set];
    }
    Class cls = object_getClass(content);
    if (!cls || [no containsObject:cls]) return NO;
    if ([yes containsObject:cls]) return YES;
    BOOL player = [NSStringFromClass(cls) containsString:@"NowPlaying_ScrollAPI"];
    [(player ? yes : no) addObject:cls];
    return player;
}

// Spotify's editor-note card for the playing song's album (Contribution_NPVCardElementKit's
// EditorNoteNPVCardElementUI, forced in behind its experiment by PlayerField.x). It is the one card kept
// below the player: its root, or a view just inside it, names EditorNote. `content` is the cell's content
// view (the NowPlaying_ScrollAPI view), as isPlayerCard() takes it.
BOOL SGRPlayerContentIsEditorNote(UIView *content) {
    if (!content || !isPlayerCard(content)) return NO;
    UIView *root = content.subviews.firstObject.subviews.firstObject;
    if (!root) return NO;
    if ([NSStringFromClass(object_getClass(root)) containsString:@"EditorNote"]) return YES;
    for (UIView *v in root.subviews)
        if ([NSStringFromClass(object_getClass(v)) containsString:@"EditorNote"]) return YES;
    return NO;
}

%hook _TtC12Element_List18CollectionViewCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)attributes {
    UICollectionViewLayoutAttributes *result = %orig;
    UIView *cell = (UIView *)self;
    UIView *content = cell.subviews.firstObject;
    if (!content || !isPlayerCard(content)) return result;
    // The one card kept: the album's editors' notes, below the player, when its switch is on (Player.h).
    // PlayerScroll.x lets the player scroll down to it; everything else still collapses to nothing.
    if (SGEnabled(SGRKeyPlayerAlbumNotes) && SGRPlayerContentIsEditorNote(content)) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{ SGLog(@"redesign player: editor-note card kept below the player"); });
        return result;
    }
    result.size = CGSizeMake(result.size.width, 0);
    cell.clipsToBounds = YES;

    static NSMutableSet<NSString *> *logged;
    if (!logged) logged = [NSMutableSet set];
    UIView *root = content.subviews.firstObject.subviews.firstObject;
    NSString *name = root ? NSStringFromClass(root.class) : @"nothing yet";
    if (![logged containsObject:name]) {
        [logged addObject:name];
        SGLog(@"redesign player: collapsed card root %@ (%lu kinds so far)", name, (unsigned long)logged.count);
    }
    return result;
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC12Element_List18CollectionViewCell"]);
}
