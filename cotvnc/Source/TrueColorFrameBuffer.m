/* TrueColorFrameBuffer.m created by helmut on Wed 23-Jun-1999 */

/* Copyright (C) 1998-2000  Helmut Maierhofer <helmut.maierhofer@chello.at>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import "TrueColorFrameBuffer.h"

//typedef	unsigned int			FBColor;

@implementation TrueColorFrameBuffer

- (id)initWithSize:(NSSize)aSize andFormat:(rfbPixelFormat*)theFormat
{
    if (self = [super initWithSize:aSize andFormat:theFormat]) {
	
		if(isBig) {
			rshift = 24;
			gshift = 16;
			bshift = 8;
		} else {
			rshift = 0;
			gshift = 8;
			bshift = 16;
		}
		maxValue = 255;
		samplesPerPixel = 3;
		bitsPerColor = 8;
		[self setPixelFormat:theFormat];
	}
    return self;
}

@end
