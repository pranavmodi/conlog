/**
 * Fetch all conversation logs from API
 * @title Fetch All Conversations
 * @category Logging
 */
const fetchAllConversations = async () => {
  try {
    const response = await fetch('http://54.71.183.198:8000/api/conversations', {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const logs = await response.json()
    return logs
  } catch (error) {
    console.error('Failed to fetch conversations:', error)
    return []
  }
}

// Execute the action
return fetchAllConversations() 