// Security Bounty Submission Tracker
// Data management and UI logic

// Load submissions from localStorage or use default data
let submissions = JSON.parse(localStorage.getItem('submissions')) || getDefaultSubmissions();

// Default submission data
function getDefaultSubmissions() {
    return [
        {
            id: 1,
            title: 'Zero-Click Apple Ecosystem Exploit Chain',
            company: 'Apple',
            status: 'ready',
            priority: 'critical',
            value: '$5M-$7M',
            caseNumber: '',
            submissionDate: '',
            notes: 'Primary submission - 8 devices, firmware bootkits, zero-click propagation',
            timeline: []
        },
        {
            id: 2,
            title: 'Firmware Bootkit Persistence (Factory Reset Bypass)',
            company: 'Apple',
            status: 'ready',
            priority: 'critical',
            value: '$2M+',
            caseNumber: '',
            submissionDate: '',
            notes: 'Factory reset does not erase firmware partitions',
            timeline: []
        },
        {
            id: 3,
            title: 'APFS B-Tree Circular Reference DoS',
            company: 'Apple',
            status: 'ready',
            priority: 'high',
            value: '$100k-$300k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Kernel driver lacks cycle detection, causes system hang',
            timeline: []
        },
        {
            id: 4,
            title: 'APFS Extended Attribute Command Injection',
            company: 'Apple',
            status: 'ready',
            priority: 'high',
            value: '$150k-$400k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Xattr command injection, Gemini parser failure evidence',
            timeline: []
        },
        {
            id: 5,
            title: 'APFS Extended Attribute Persistence',
            company: 'Apple',
            status: 'ready',
            priority: 'high',
            value: '$200k-$500k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Irremovable xattrs, 15,008 files affected',
            timeline: []
        },
        {
            id: 6,
            title: 'Time Machine Snapshot Bomb',
            company: 'Apple',
            status: 'ready',
            priority: 'high',
            value: '$150k-$300k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Weaponized snapshots trigger DoS on mount',
            timeline: []
        },
        {
            id: 7,
            title: 'NFS Extended Attribute DoS (Compression Bomb)',
            company: 'Apple',
            status: 'ready',
            priority: 'medium',
            value: '$50k-$100k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Poisoned xattrs cause NFS metadata storm',
            timeline: []
        },
        {
            id: 8,
            title: 'Claude Desktop Unauthorized Filesystem Access',
            company: 'Anthropic',
            status: 'ready',
            priority: 'high',
            value: '$100k-$200k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Unauthorized access during APT attack',
            timeline: []
        },
        {
            id: 9,
            title: 'Sony BRAVIA TV - Google Auth Bypass',
            company: 'Sony',
            status: 'ready',
            priority: 'high',
            value: '$200k-$400k',
            caseNumber: '',
            submissionDate: '',
            notes: 'TV used as C2 platform, 57,949 connections',
            timeline: []
        },
        {
            id: 10,
            title: 'Ubiquiti UDM Pro Firewall Bypass',
            company: 'Ubiquiti',
            status: 'ready',
            priority: 'medium',
            value: '$50k-$100k',
            caseNumber: '',
            submissionDate: '',
            notes: 'Network gateway compromise',
            timeline: []
        }
    ];
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', function() {
    renderSubmissions();
    updateStats();
    setupFilters();
});

// Render submissions table
function renderSubmissions(filter = 'all') {
    const tbody = document.getElementById('submissions-body');
    tbody.innerHTML = '';

    let filtered = submissions;

    if (filter !== 'all') {
        if (['ready', 'submitted', 'reviewing', 'acknowledged', 'paid'].includes(filter)) {
            filtered = submissions.filter(s => s.status === filter);
        } else {
            filtered = submissions.filter(s => s.company.toLowerCase() === filter);
        }
    }

    filtered.forEach(sub => {
        const row = document.createElement('tr');
        row.innerHTML = `
            <td>
                <strong>${sub.title}</strong>
                ${sub.notes ? `<div class="notes">${sub.notes}</div>` : ''}
            </td>
            <td>
                <span class="company-filter company-${sub.company.toLowerCase()}">${sub.company}</span>
            </td>
            <td>
                <span class="status-badge status-${sub.status}">${sub.status}</span>
            </td>
            <td class="priority-${sub.priority}">
                ${sub.priority.toUpperCase()}
            </td>
            <td class="value">${sub.value}</td>
            <td>${sub.caseNumber || '-'}</td>
            <td class="actions">
                <button class="btn" onclick="editSubmission(${sub.id})">Edit</button>
                <button class="btn" onclick="viewDetails(${sub.id})">Details</button>
            </td>
        `;
        tbody.appendChild(row);
    });
}

// Update statistics
function updateStats() {
    const ready = submissions.filter(s => s.status === 'ready').length;
    const paid = submissions.filter(s => s.status === 'paid');
    const paidAmount = paid.reduce((sum, s) => {
        // Extract numeric value from string like "$100k-$200k"
        const match = s.value.match(/\$?(\d+(?:\.\d+)?)[kKmM]/);
        if (match) {
            const num = parseFloat(match[1]);
            const unit = s.value.match(/[kKmM]/)[0].toLowerCase();
            return sum + (unit === 'k' ? num * 1000 : num * 1000000);
        }
        return sum;
    }, 0);

    document.getElementById('total-submissions').textContent = submissions.length;
    document.getElementById('ready-count').textContent = ready;
    document.getElementById('paid-count').textContent = formatMoney(paidAmount);
}

// Format money
function formatMoney(amount) {
    if (amount === 0) return '$0';
    if (amount >= 1000000) return '$' + (amount / 1000000).toFixed(1) + 'M';
    if (amount >= 1000) return '$' + (amount / 1000).toFixed(0) + 'k';
    return '$' + amount;
}

// Setup filter buttons
function setupFilters() {
    document.querySelectorAll('.filter-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            // Remove active class from all buttons
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            // Add active class to clicked button
            this.classList.add('active');
            // Filter submissions
            const filter = this.dataset.filter;
            renderSubmissions(filter);
        });
    });
}

// Modal functions
function openAddModal() {
    document.getElementById('modal-title').textContent = 'Add Submission';
    document.getElementById('submission-form').reset();
    document.getElementById('submission-modal').style.display = 'block';
}

function closeModal() {
    document.getElementById('submission-modal').style.display = 'none';
}

function editSubmission(id) {
    const sub = submissions.find(s => s.id === id);
    if (!sub) return;

    document.getElementById('modal-title').textContent = 'Edit Submission';
    document.getElementById('form-title').value = sub.title;
    document.getElementById('form-company').value = sub.company;
    document.getElementById('form-status').value = sub.status;
    document.getElementById('form-priority').value = sub.priority;
    document.getElementById('form-value').value = sub.value;
    document.getElementById('form-case').value = sub.caseNumber || '';
    document.getElementById('form-date').value = sub.submissionDate || '';
    document.getElementById('form-notes').value = sub.notes || '';

    document.getElementById('submission-form').dataset.editId = id;
    document.getElementById('submission-modal').style.display = 'block';
}

function viewDetails(id) {
    const sub = submissions.find(s => s.id === id);
    if (!sub) return;

    alert(`Submission Details:\n\nTitle: ${sub.title}\nCompany: ${sub.company}\nStatus: ${sub.status}\nPriority: ${sub.priority}\nValue: ${sub.value}\nCase Number: ${sub.caseNumber || 'Not assigned'}\nSubmission Date: ${sub.submissionDate || 'Not submitted'}\n\nNotes: ${sub.notes || 'None'}`);
}

// Form submission
document.getElementById('submission-form').addEventListener('submit', function(e) {
    e.preventDefault();

    const editId = this.dataset.editId;
    const formData = {
        title: document.getElementById('form-title').value,
        company: document.getElementById('form-company').value,
        status: document.getElementById('form-status').value,
        priority: document.getElementById('form-priority').value,
        value: document.getElementById('form-value').value,
        caseNumber: document.getElementById('form-case').value,
        submissionDate: document.getElementById('form-date').value,
        notes: document.getElementById('form-notes').value,
        timeline: []
    };

    if (editId) {
        // Edit existing
        const index = submissions.findIndex(s => s.id === parseInt(editId));
        if (index !== -1) {
            submissions[index] = { ...submissions[index], ...formData };

            // Add timeline event
            const oldStatus = submissions[index].status;
            if (oldStatus !== formData.status) {
                submissions[index].timeline.push({
                    date: new Date().toISOString().split('T')[0],
                    event: `Status changed from ${oldStatus} to ${formData.status}`
                });
            }
        }
        delete this.dataset.editId;
    } else {
        // Add new
        const newId = Math.max(...submissions.map(s => s.id), 0) + 1;
        submissions.push({ id: newId, ...formData });
    }

    // Save to localStorage
    localStorage.setItem('submissions', JSON.stringify(submissions));

    // Update UI
    renderSubmissions();
    updateStats();
    closeModal();
});

// Close modal when clicking outside
window.onclick = function(event) {
    const modal = document.getElementById('submission-modal');
    if (event.target === modal) {
        closeModal();
    }
};

// Export functions
function exportToJSON() {
    const dataStr = JSON.stringify(submissions, null, 2);
    const dataBlob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'submissions-' + new Date().toISOString().split('T')[0] + '.json';
    link.click();
}

function exportToMarkdown() {
    let md = '# Security Bounty Submissions\n\n';
    md += `**Last Updated:** ${new Date().toISOString().split('T')[0]}\n\n`;
    md += `**Total Submissions:** ${submissions.length}\n\n`;
    md += '---\n\n';

    submissions.forEach(sub => {
        md += `## ${sub.title}\n\n`;
        md += `- **Company:** ${sub.company}\n`;
        md += `- **Status:** ${sub.status}\n`;
        md += `- **Priority:** ${sub.priority}\n`;
        md += `- **Value:** ${sub.value}\n`;
        if (sub.caseNumber) md += `- **Case Number:** ${sub.caseNumber}\n`;
        if (sub.submissionDate) md += `- **Submission Date:** ${sub.submissionDate}\n`;
        if (sub.notes) md += `- **Notes:** ${sub.notes}\n`;
        md += '\n---\n\n';
    });

    const dataBlob = new Blob([md], { type: 'text/markdown' });
    const url = URL.createObjectURL(dataBlob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'submissions-' + new Date().toISOString().split('T')[0] + '.md';
    link.click();
}

// Add keyboard shortcuts
document.addEventListener('keydown', function(e) {
    // Escape to close modal
    if (e.key === 'Escape') {
        closeModal();
    }
    // Ctrl/Cmd + N to add new submission
    if ((e.ctrlKey || e.metaKey) && e.key === 'n') {
        e.preventDefault();
        openAddModal();
    }
});
