import { createConsumer } from "@rails/actioncable"

const consumer = createConsumer()

consumer.subscriptions.create("JobsChannel", {
  connected() {
    console.log("JobsChannel connected")
  },
  
  disconnected() {
    console.log("JobsChannel disconnected")
  },
  
  received(data) {
    console.log("JobsChannel received:", data)
    if (["job_enqueued", "job_performed", "job_discarded", "job_retried", "job_succeeded"].includes(data.type)) {
      // Refresh stats and jobs frames by triggering a reload
      const statsFrame = document.getElementById("stats_frame")
      const jobsFrame = document.getElementById("jobs_frame")
      
      // Helper function to reload a Turbo Frame
      const reloadFrame = (frame) => {
        if (!frame) return
        
        const currentSrc = frame.getAttribute("src") || frame.src
        if (currentSrc) {
          // Remove src to force a reload
          frame.removeAttribute("src")
          // Use a small delay to ensure Turbo processes the change
          setTimeout(() => {
            frame.src = currentSrc
          }, 100)
        }
      }
      
      // Reload both frames with a slight delay between them
      reloadFrame(statsFrame)
      setTimeout(() => {
        reloadFrame(jobsFrame)
      }, 50)
    }
  }
})

