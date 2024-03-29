//
//  MapViewController.m
//  Utah Bus
//
//  Created by Ravi Alla on 8/6/12.
//  Copyright (c) 2012 Ravi Alla. All rights reserved.
//  Displays the map to show vehicles that are being tracked

#import "MapViewController.h"
#import "LocationAnnotation.h"
#import "UtaFetcher.h"
#import "StopTableViewController.h"
#import "UTAViewController.h"
#import "timetableViewController.h"

@interface MapViewController () <MKMapViewDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIButton *typeDetailDisclosure;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) NSString *progress;
@property (strong, nonatomic) NSMutableArray *directionOfVehicle;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *addToFaves;
@property (nonatomic) MKCoordinateRegion defaultZoom;
@property (nonatomic) MKCoordinateRegion currentZoom;
@property (nonatomic, strong) NSString *direction;
@property (nonatomic) BOOL refreshPressed;

@end

@implementation MapViewController
@synthesize addToFaves = _addToFaves;
@synthesize mapView = _mapView;
@synthesize direction = _direction;

@synthesize annotations = _annotations;
@synthesize  vehicleInfo = _vehicleInfo;
@synthesize currentLocation = _currentLocation;
@synthesize locationManager = _locationManager;
@synthesize progress = _progress;
@synthesize shape_lon = _shape_lon;
@synthesize shape_lt = _shape_lt;
@synthesize refreshDelegate = _refreshDelegate;
@synthesize dictOfShapeArrays = _dictOfShapeArrays;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

// update method for when the annotations or mapview is updated
-(void) updateMapView
{
    if (self.mapView.annotations)[self.mapView removeAnnotations:self.mapView.annotations];
    if (self.annotations){
        [self updateLocation];
        [self.mapView addAnnotations:self.annotations];
    }
   
// Setting the initial zoom based on the highest and lowest values of the latitudes and longitudes of the buses' locations
    if ([self.annotations count]!= 0 || [self.shape_lon count]!=0){
        NSMutableArray *latitude = [NSMutableArray arrayWithArray:self.shape_lt];
    NSMutableArray *longitude = [NSMutableArray arrayWithArray:self.shape_lon];
        for (LocationAnnotation *annotation in self.annotations){
        self.vehicleInfo = [annotation vehicleInfo];
            if (!self.directionOfVehicle)self.directionOfVehicle = [NSMutableArray array];
            if (![self.directionOfVehicle containsObject:[self.vehicleInfo objectForKey:DIRECTION_OF_VEHICLE]]){
                [self.directionOfVehicle addObject:[self.vehicleInfo objectForKey:DIRECTION_OF_VEHICLE]];
            }
    }
    NSArray* sortedlatitude = [latitude sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
        return ([obj1 doubleValue] < [obj2 doubleValue]);
    }];
    
    NSArray* sortedlongitude = [longitude sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2){
        return ([obj1 doubleValue] < [obj2 doubleValue]);
    }];
        if ([self.shape_lon count]!=0){
    MKCoordinateRegion zoomRegion;
    zoomRegion.center.latitude = ([[sortedlatitude objectAtIndex:0] doubleValue]+[[sortedlatitude lastObject]doubleValue])/2;
    zoomRegion.center.longitude = ([[sortedlongitude objectAtIndex:0]doubleValue]+[[sortedlongitude lastObject]doubleValue])/2;
    double latitudeDelta = [[sortedlatitude lastObject]doubleValue]-[[sortedlatitude objectAtIndex:0]doubleValue];
    double longitudeDelta = [[sortedlongitude lastObject]doubleValue]-[[sortedlongitude objectAtIndex:0]doubleValue];
    if (latitudeDelta < 0) latitudeDelta = -1*latitudeDelta;
    if (longitudeDelta <0) longitudeDelta = -1*longitudeDelta;
    zoomRegion.span.latitudeDelta = latitudeDelta;
    zoomRegion.span.longitudeDelta = longitudeDelta;
    if (zoomRegion.span.latitudeDelta==0) zoomRegion.span.latitudeDelta = 0.2;
    if (zoomRegion.span.longitudeDelta == 0) zoomRegion.span.longitudeDelta = 0.2;
    if (!self.currentZoom.span.latitudeDelta)self.currentZoom = zoomRegion;
    [self.mapView setRegion:self.currentZoom animated:YES];
    }
    else if (self.refreshPressed) [self.mapView setRegion:self.currentZoom animated:YES];
    }
// protecting against a crash when utafetcher returns empty stuff for whatever reason
    else {
    MKCoordinateRegion zoomRegion;
    zoomRegion.center.latitude = 40.760779;
    zoomRegion.center.longitude = -111.891047;
    zoomRegion.span.latitudeDelta = 0.8;
    zoomRegion.span.longitudeDelta = 0.8;
    self.defaultZoom = zoomRegion;
    [self.mapView setRegion:self.defaultZoom animated:YES];
}
   
// creating a polyline for each route map and adding it to the map
    if (self.dictOfShapeArrays){
        for (NSString *shapeID in self.dictOfShapeArrays){
            NSArray *shapeCoordinates = [self.dictOfShapeArrays valueForKey:shapeID];
            int numberofSteps = [shapeCoordinates count];
            CLLocationCoordinate2D coordinates [numberofSteps];
            for (CLLocation *shapeLocationCoordinate in shapeCoordinates){
                CLLocationCoordinate2D shapeCoordinate = [shapeLocationCoordinate coordinate];
                coordinates [[shapeCoordinates indexOfObject:shapeLocationCoordinate]] = shapeCoordinate;
            }
                
            MKPolyline *polyLine = [MKPolyline polylineWithCoordinates:coordinates count:[shapeCoordinates count]];
            polyLine.title = shapeID;
            [self.mapView addOverlay:polyLine];
        }
    }

}

//setting up the annotations and customizing the rightcalloutaccessory
- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    NSString *direction = [[NSString alloc]init];
        direction = [annotation subtitle];
    if (![annotation isKindOfClass:[MKUserLocation class]]){
            MKPinAnnotationView *aView =(MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"Bus Coordinates"];
            aView = nil;//[[MKPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:@"Bus Coordinates"];
            if (!aView){
                aView = [[MKPinAnnotationView alloc]initWithAnnotation:annotation reuseIdentifier:@"Bus Coordinates"];
                aView.canShowCallout = YES;
            }
            aView.canShowCallout = YES;
            if ([direction isEqualToString:[self.directionOfVehicle objectAtIndex:0]]){
            aView.pinColor = MKPinAnnotationColorPurple;
            }
            else aView.pinColor = MKPinAnnotationColorRed;
            aView.annotation = annotation;
            aView.leftCalloutAccessoryView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, 30, 30)];
            self.typeDetailDisclosure = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            aView.rightCalloutAccessoryView =self.typeDetailDisclosure;
            return aView;
            }
    else return nil;

}

// refresh the map when the refresh button is pressed, I had to exclude running the refresh on another thread because the annotations were not being loaded properly..work around for now
- (void)refreshMap:(id)sender {
    self.refreshPressed = YES;
    NSString *route = [self.vehicleInfo objectForKey:LINE_NAME];
    //self.annotations = [self.refreshDelegate refreshedAnnotations:route :self];
    //dispatch_queue_t xmlGetter = dispatch_queue_create("UTA xml getter", NULL);
    //dispatch_async(xmlGetter, ^{
       //self.annotations = nil;
        self.currentZoom = self.mapView.region;
        self.annotations = [self.refreshDelegate refreshedAnnotations:route :self];
        for (LocationAnnotation *annotation in self.annotations){
            if ([self.mapView.annotations count]>0)[self.mapView removeAnnotation:annotation];
        }
        [self.mapView addAnnotations:self.annotations];
        CLLocationCoordinate2D center = [self.mapView centerCoordinate];
        [self.mapView setCenterCoordinate:center];
        
        //dispatch_async(dispatch_get_main_queue(), ^{
        //});
    //});
    //dispatch_release(xmlGetter);
    //self.typeDetailDisclosure = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
    self.refreshPressed = NO;
}

- (void) mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated
{
    self.currentZoom = mapView.region;
}

// draw the polyline onto the map, setting line stroke width and color as well
- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
    MKPolylineView *polylineView = [[MKPolylineView alloc] initWithPolyline:overlay];
    polylineView.strokeColor = [UIColor redColor];
    polylineView.lineWidth = 2.0;
    
    return polylineView;
}

// add the current route to favorites
- (IBAction)addToFavorites:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *favorites = [[defaults objectForKey:@"favorite.routes"] mutableCopy];
    NSArray *routeInfo = [NSArray arrayWithObjects:[self.vehicleInfo objectForKey:PUBLISHED_LINE_NAME],[self.vehicleInfo objectForKey:LINE_NAME],nil];
    if (!favorites) favorites = [NSMutableArray array];
    //add only if the routeInfo returns a short and long name, the route count is checking for that here
    if (favorites && ![favorites containsObject:routeInfo]&&[routeInfo count]!=0) [favorites addObject:routeInfo];
    [defaults setObject:favorites forKey:@"favorite.routes"];
    [defaults synchronize];
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    self.vehicleInfo = [(LocationAnnotation *)view.annotation vehicleInfo];
    if (self.vehicleInfo){
        [self performSegueWithIdentifier:@"show timetable" sender:view.rightCalloutAccessoryView];
        }
}


// assigning a colored dot based on the current progress of the bus
- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKPinAnnotationView *)view
{
    if ([view.annotation isKindOfClass:[LocationAnnotation class]]){
    self.vehicleInfo = [(LocationAnnotation *)view.annotation vehicleInfo];
    NSString *progress = [self.vehicleInfo objectForKey:PROGRESS_RATE];
    CGRect progressRect = CGRectMake(0, 0, 20, 20);
    UIGraphicsBeginImageContext(progressRect.size);
    CGContextBeginPath(UIGraphicsGetCurrentContext());
    CGContextAddArc(UIGraphicsGetCurrentContext(), 10, 10, 2, 0, 2*M_PI, YES);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), 5.0);
    if ([progress isEqualToString:@"0"]) [[UIColor blueColor]setStroke];
    if ([progress isEqualToString:@"1"]) [[UIColor greenColor]setStroke];
    if ([progress isEqualToString:@"2"]) [[UIColor orangeColor]setStroke];
    if ([progress isEqualToString:@"3"]) [[UIColor redColor]setStroke];
    if ([progress isEqualToString:@"4"]) [[UIColor lightGrayColor]setStroke];
    if ([progress isEqualToString:@"5"]) [[UIColor whiteColor]setStroke];

    CGContextStrokePath(UIGraphicsGetCurrentContext());
    UIImage *progressImage = UIGraphicsGetImageFromCurrentImageContext();
    [(UIImageView*)view.leftCalloutAccessoryView setImage:progressImage];
    if (view.pinColor==MKPinAnnotationColorRed)self.direction = @"1";
    else self.direction = @"0";
    }
}


// seguing to a tableviewcontroller to show the stops that the selected bus makes
- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"show timetable"]){
        [segue.destinationViewController setRoute:[self.vehicleInfo objectForKey:LINE_NAME]];
        [segue.destinationViewController setVehicleDirection:self.direction];
    }
}
- (void) setMapView:(MKMapView *)mapView
{
    _mapView = mapView;
    [self updateMapView];
}

- (void) setAnnotations:(NSArray *)annotations
{
    _annotations = annotations;
    [self updateMapView];
}

- (CLLocationManager *) locationManager
{
    if (!_locationManager){
        _locationManager = [[CLLocationManager alloc]init];
    }
    return _locationManager;
}

// In here I am getting the users current location

- (void)updateLocation
{
    self.mapView.delegate = self;
    self.locationManager.delegate = self;
    self.locationManager.distanceFilter = kCLDistanceFilterNone; // whenever we move
    self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters; // 10 m
    [self.locationManager startUpdatingLocation];
    [self.mapView setShowsUserLocation:YES];
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateLocation];
    //if (self.shape_lon)self.shape_lon = nil;
    //if (self.shape_lt) self.shape_lt = nil;
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [self setMapView:nil];
    [self setAnnotations:nil];
    [self setAddToFaves:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void) viewWillAppear:(BOOL)animated
{
    LocationAnnotation *la = (LocationAnnotation *) [self.annotations lastObject];
    NSString *title= la.title;
    self.navigationItem.title = title;
    UILabel* tlabel=[[UILabel alloc] initWithFrame:CGRectMake(0,0, 150, 40)];
    tlabel.text=self.navigationItem.title;
    tlabel.textColor=[UIColor whiteColor];
    tlabel.backgroundColor =[UIColor clearColor];
    tlabel.adjustsFontSizeToFitWidth=YES;
    [tlabel setTextAlignment:NSTextAlignmentCenter];
    self.navigationItem.titleView=tlabel;
    NSMutableArray *buttons = [[NSMutableArray alloc] initWithCapacity:3];
    
    // Create a standard refresh button.
    UIBarButtonItem *bi = [[UIBarButtonItem alloc]
                           initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshMap:)];
    [buttons addObject:bi];
    // Add profile button.
    bi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:self action:@selector(addToFavorites:)];
    bi.style = UIBarButtonItemStyleBordered;
    [buttons addObject:bi];
    
    // Add buttons to toolbar and toolbar to nav bar.
    self.navigationItem.rightBarButtonItems=buttons;
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

@end
