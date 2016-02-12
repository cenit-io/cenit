$(function () {
    $('#take-tour').click(function(e){
        e.preventDefault();
        var tour = new Tour({
            name: 'anonymous',
            steps: [
                {
                    title: "Welcome to Cenit",
                    content: "Thanks for visiting us! Click 'Next' to start the tour.",
                    orphan: true
                },
                {
                    title: "Step 2",
                    content: "Thanks for visiting us! Click 'Next' to start the tour.",
                    orphan: true
                },
                {
                    title: "Step 3",
                    content: "Thanks for visiting us! Click 'Next' to start the tour.",
                    orphan: true
                }
            ]});
// Initialize the tour
        tour.init();

// Start the tour
        tour.start(true);
    });
});
