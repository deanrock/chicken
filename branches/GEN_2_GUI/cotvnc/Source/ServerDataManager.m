//
//  ServerManager.m
//  Chicken of the VNC
//
//  Created by Jared McIntyre on Sat Jan 24 2004.
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

#import "ServerDataManager.h"
#import "ServerFromPrefs.h"
#import <AppKit/AppKit.h>

#define RFB_PREFS_LOCATION  @"Library/Preferences/cotvnc.prefs"
#define RFB_HOST_INFO		@"HostPreferences"
#define RFB_SERVER_LIST     @"ServerList"
#define RFB_GROUP_LIST		@"GroupList"
#define RFB_SAVED_SERVERS   @"SavedServers"

@implementation ServerDataManager

static ServerDataManager* gInstance = nil;

+ (void)initialize
{
	[ServerDataManager setVersion:1];
}

- (id)init
{
	if( self = [super init] )
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification object:NSApp];
		
		mServers = [[NSMutableDictionary alloc] init];
		mGroups  = [[NSMutableDictionary alloc] init];
		
		[mGroups setObject:[NSMutableArray array] forKey:@"All"];
		[mGroups setObject:[NSMutableArray array] forKey:@"Rendezvous"];
		[mGroups setObject:[NSMutableArray array] forKey:@"Standard"];
	}
	
	return self;
}

- (id)initWithOriginalPrefs
{
	if( self = [self init] )
	{
		NSEnumerator* hostEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:RFB_HOST_INFO] keyEnumerator];
		NSEnumerator* objEnumerator = [[[NSUserDefaults standardUserDefaults] objectForKey:RFB_HOST_INFO] objectEnumerator];
		NSString* host;
		NSDictionary* obj;
		while( host = [hostEnumerator nextObject] )
		{
			obj = [objEnumerator nextObject];
			id<IServerData> server = [ServerFromPrefs createWithHost:host preferenceDictionary:obj];
			if( nil != server )
			{
				[server setDelegate:self];
				[mServers setObject:server forKey:[server name]];
			}
		}
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self save];
		
    [mServers release];
	[mGroups release];
    [super dealloc];
}

- (void)save
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject: gInstance];
	[[NSUserDefaults standardUserDefaults] setObject: data forKey: RFB_SAVED_SERVERS];
}

+ (ServerDataManager*) sharedInstance
{
	if( nil == gInstance )
	{
		NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:RFB_SAVED_SERVERS];
		if ( data )
		{
			gInstance = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			[gInstance retain];
		}
		
		if( nil == gInstance )
		{
			NSString *storePath = [NSHomeDirectory() stringByAppendingPathComponent:RFB_PREFS_LOCATION];
			
			gInstance = [NSKeyedUnarchiver unarchiveObjectWithFile:storePath];
			[gInstance retain];
			if( nil == gInstance )
			{
				// Didn't find any preferences under the new serialization system,
				// load based on the old system
				gInstance = [[ServerDataManager alloc] initWithOriginalPrefs];
				
				[gInstance save];
			}
		}
	}
	
	return gInstance;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    NSParameterAssert( [coder allowsKeyedCoding] );

	[coder encodeObject:mServers forKey:RFB_SERVER_LIST];
	[coder encodeObject:mGroups forKey:RFB_GROUP_LIST];
    
	return;
}

- (id)initWithCoder:(NSCoder *)coder
{
	[self autorelease];
	NSParameterAssert( [coder allowsKeyedCoding] );
	[self retain];
			
	if( self = [self init] )
	{
		[mServers release];
		mServers = [[coder decodeObjectForKey:RFB_SERVER_LIST] retain];
		
		[mGroups release];
		mGroups = [[coder decodeObjectForKey:RFB_GROUP_LIST] retain];
		
		id<IServerData> server;
		NSEnumerator* objEnumerator = [mServers objectEnumerator];
		while( server = [objEnumerator nextObject] )
		{
			[server setDelegate:self];
		}
	}
	
    return self;
}


- (void)applicationWillTerminate:(NSNotification *)notification
{
	[gInstance release];
}

- (unsigned) serverCount
{
	return [mServers count];
}

- (NSEnumerator*) getServerEnumerator
{
	return [mServers objectEnumerator];
}

- (unsigned) groupCount
{
	return [mGroups count];
}

- (NSEnumerator*) getGroupNameEnumerator
{
	return [mGroups keyEnumerator];
}

- (id<IServerData>)getServerWithName:(NSString*)name
{
	return [mServers objectForKey:name];
}

- (id<IServerData>)getServerAtIndex:(int)index
{
	if( 0 > index )
	{
		return nil;
	}
	
	return [[mServers allValues] objectAtIndex:index];
}

- (void)removeServer:(id<IServerData>)server
{
	[mServers removeObjectForKey:[server name]];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
}

- (void)makeNameUnique:(NSMutableString*)name
{
	if(nil != [mServers objectForKey:name])
	{
		int numHelper = 0;
		NSString* newName;
		do
		{
			numHelper++;
			newName = [NSString stringWithFormat:@"%@_%d", name, numHelper];
		}while( nil != [mServers objectForKey:newName] );
		
		[name setString: newName];
	}
}

- (id<IServerData>)createServerByName:(NSString*)name
{
	NSMutableString *nameHelper = [NSMutableString stringWithString:name];
	
	[self makeNameUnique:nameHelper];
	
	ServerFromPrefs* newServer = [ServerFromPrefs createWithName:nameHelper];
	[mServers setObject:newServer forKey:[newServer name]];
	
	assert( nil != [mServers objectForKey:nameHelper] );
	assert( newServer == [mServers objectForKey:nameHelper] );
	
	[newServer setDelegate:self];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:ServerListChangeMsg
														object:self];
	
	return newServer;
}

- (void)validateNameChange:(NSMutableString *)name forServer:(id<IServerData>)server;
{
	if( nil != [mServers objectForKey:[server name]] )
	{
		NSParameterAssert( server == [mServers objectForKey:[server name]] );
		
		[(NSObject *)server retain];
		
		[mServers removeObjectForKey:[server name]];
		[self makeNameUnique:name];
		[mServers setObject:server forKey:name];
		
		[(NSObject *)server release];
	}
}
@end
